/*
 * Copyright (c) 2022 Pablo Neira Ayuso <pablo@netfilter.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 (or any
 * later) as published by the Free Software Foundation.
 */

#include <nftables.h>
#include <expression.h>
#include <intervals.h>
#include <rule.h>

static void setelem_expr_to_range(struct expr *expr)
{
	unsigned char data[sizeof(struct in6_addr) * BITS_PER_BYTE];
	struct expr *key, *value;
	mpz_t rop;

	assert(expr->etype == EXPR_SET_ELEM);

	switch (expr->key->etype) {
	case EXPR_RANGE:
		break;
	case EXPR_PREFIX:
		mpz_init(rop);
		mpz_bitmask(rop, expr->key->len - expr->key->prefix_len);
		mpz_ior(rop, rop, expr->key->prefix->value);
	        mpz_export_data(data, rop, expr->key->prefix->byteorder,
				expr->key->prefix->len / BITS_PER_BYTE);
		mpz_clear(rop);
		value = constant_expr_alloc(&expr->location,
					    expr->key->prefix->dtype,
					    expr->key->prefix->byteorder,
					    expr->key->prefix->len, data);
		key = range_expr_alloc(&expr->location,
				       expr_get(expr->key->prefix),
				       value);
		expr_free(expr->key);
		expr->key = key;
		break;
	case EXPR_VALUE:
		key = range_expr_alloc(&expr->location,
				       expr_clone(expr->key),
				       expr_get(expr->key));
		expr_free(expr->key);
		expr->key = key;
		break;
	default:
		assert(1);
	}
}

static void remove_overlapping_range(struct expr *i, struct expr *init)
{
	list_del(&i->list);
	expr_free(i);
	init->size--;
}

struct range {
	mpz_t	low;
	mpz_t	high;
};

static void merge_ranges(struct expr *prev, struct expr *i,
			 struct range *prev_range, struct range *range,
			 struct expr *init)
{
	expr_free(prev->key->right);
	prev->key->right = expr_get(i->key->right);
	list_del(&i->list);
	expr_free(i);
	mpz_set(prev_range->high, range->high);
	init->size--;
}

static void setelem_automerge(struct list_head *msgs, struct set *set,
			      struct expr *init)
{
	struct expr *i, *next, *prev = NULL;
	struct range range, prev_range;
	mpz_t rop;

	mpz_init(prev_range.low);
	mpz_init(prev_range.high);
	mpz_init(range.low);
	mpz_init(range.high);
	mpz_init(rop);

	list_for_each_entry_safe(i, next, &init->expressions, list) {
		if (i->key->etype == EXPR_SET_ELEM_CATCHALL)
			continue;

		range_expr_value_low(range.low, i);
		range_expr_value_high(range.high, i);

		if (!prev) {
			prev = i;
			mpz_set(prev_range.low, range.low);
			mpz_set(prev_range.high, range.high);
			continue;
		}

		if (mpz_cmp(prev_range.low, range.low) <= 0 &&
		    mpz_cmp(prev_range.high, range.high) >= 0) {
			remove_overlapping_range(i, init);
			continue;
		} else if (mpz_cmp(range.low, prev_range.high) <= 0) {
			merge_ranges(prev, i, &prev_range, &range, init);
			continue;
		} else if (set->automerge) {
			mpz_sub(rop, range.low, prev_range.high);
			/* two contiguous ranges */
			if (mpz_cmp_ui(rop, 1) == 0) {
				merge_ranges(prev, i, &prev_range, &range, init);
				continue;
			}
		}

		prev = i;
		mpz_set(prev_range.low, range.low);
		mpz_set(prev_range.high, range.high);
	}

	mpz_clear(prev_range.low);
	mpz_clear(prev_range.high);
	mpz_clear(range.low);
	mpz_clear(range.high);
	mpz_clear(rop);
}

static struct expr *interval_expr_key(struct expr *i)
{
	struct expr *elem;

	switch (i->etype) {
	case EXPR_MAPPING:
		elem = i->left;
		break;
	case EXPR_SET_ELEM:
		elem = i;
		break;
	default:
		assert(1);
		return NULL;
	}

	return elem;
}

void set_to_range(struct expr *init)
{
	struct expr *i, *elem;

	list_for_each_entry(i, &init->expressions, list) {
		elem = interval_expr_key(i);
		setelem_expr_to_range(elem);
	}

	list_expr_sort(&init->expressions);
}

int set_automerge(struct list_head *msgs, struct set *set, struct expr *init)
{
	set_to_range(init);

	if (set->flags & NFT_SET_MAP)
		return 0;

	setelem_automerge(msgs, set, init);

	return 0;
}

static int setelem_overlap(struct list_head *msgs, struct set *set,
			   struct expr *init)
{
	struct expr *i, *next, *elem, *prev = NULL;
	struct range range, prev_range;
	int err = 0;
	mpz_t rop;

	mpz_init(prev_range.low);
	mpz_init(prev_range.high);
	mpz_init(range.low);
	mpz_init(range.high);
	mpz_init(rop);

	list_for_each_entry_safe(elem, next, &init->expressions, list) {
		i = interval_expr_key(elem);

		if (i->key->etype == EXPR_SET_ELEM_CATCHALL)
			continue;

		range_expr_value_low(range.low, i);
		range_expr_value_high(range.high, i);

		if (!prev) {
			prev = elem;
			mpz_set(prev_range.low, range.low);
			mpz_set(prev_range.high, range.high);
			continue;
		}

		if (mpz_cmp(prev_range.low, range.low) == 0 &&
		    mpz_cmp(prev_range.high, range.high) == 0 &&
		    (elem->flags & EXPR_F_KERNEL || prev->flags & EXPR_F_KERNEL))
			goto next;

		if (mpz_cmp(prev_range.low, range.low) <= 0 &&
		    mpz_cmp(prev_range.high, range.high) >= 0) {
			if (prev->flags & EXPR_F_KERNEL)
				expr_error(msgs, i, "interval overlaps with an existing one");
			else if (elem->flags & EXPR_F_KERNEL)
				expr_error(msgs, prev, "interval overlaps with an existing one");
			else
				expr_binary_error(msgs, i, prev,
						  "conflicting intervals specified");
			err = -1;
			goto err_out;
		} else if (mpz_cmp(range.low, prev_range.high) <= 0) {
			if (prev->flags & EXPR_F_KERNEL)
				expr_error(msgs, i, "interval overlaps with an existing one");
			else if (elem->flags & EXPR_F_KERNEL)
				expr_error(msgs, prev, "interval overlaps with an existing one");
			else
				expr_binary_error(msgs, i, prev,
						  "conflicting intervals specified");
			err = -1;
			goto err_out;
		}
next:
		prev = elem;
		mpz_set(prev_range.low, range.low);
		mpz_set(prev_range.high, range.high);
	}

err_out:
	mpz_clear(prev_range.low);
	mpz_clear(prev_range.high);
	mpz_clear(range.low);
	mpz_clear(range.high);
	mpz_clear(rop);

	return err;
}

/* overlap detection for intervals already exists in Linux kernels >= 5.7. */
int set_overlap(struct list_head *msgs, struct set *set, struct expr *init)
{
	struct set *existing_set = set->existing_set;
	struct expr *i, *n;
	int err;

	if (existing_set && existing_set->init) {
		list_splice_init(&existing_set->init->expressions,
				 &init->expressions);
	}

	set_to_range(init);

	err = setelem_overlap(msgs, set, init);

	list_for_each_entry_safe(i, n, &init->expressions, list) {
		if (i->flags & EXPR_F_KERNEL)
			list_move_tail(&i->list, &existing_set->init->expressions);
	}

	return err;
}

static bool segtree_needs_first_segment(const struct set *set,
					const struct expr *init, bool add)
{
	if (add && !set->root) {
		/* Add the first segment in four situations:
		 *
		 * 1) This is an anonymous set.
		 * 2) This set exists and it is empty.
		 * 3) New empty set and, separately, new elements are added.
		 * 4) This set is created with a number of initial elements.
		 */
		if ((set_is_anonymous(set->flags)) ||
		    (set->init && set->init->size == 0) ||
		    (set->init == NULL && init) ||
		    (set->init == init)) {
			return true;
		}
	}
	/* This is an update for a set that already contains elements, so don't
	 * add the first non-matching elements otherwise we hit EEXIST.
	 */
	return false;
}

int set_to_intervals(const struct set *set, struct expr *init, bool add)
{
	struct expr *i, *n, *prev = NULL, *elem, *newelem = NULL, *root, *expr;
	LIST_HEAD(intervals);
	uint32_t flags;
	mpz_t p, q;

	mpz_init2(p, set->key->len);
	mpz_init2(q, set->key->len);

	list_for_each_entry_safe(i, n, &init->expressions, list) {
		flags = 0;

		elem = interval_expr_key(i);

		if (elem->key->etype == EXPR_SET_ELEM_CATCHALL)
			continue;

		if (!prev && segtree_needs_first_segment(set, init, add) &&
		    mpz_cmp_ui(elem->key->left->value, 0)) {
			mpz_set_ui(p, 0);
			expr = constant_expr_alloc(&internal_location,
						   set->key->dtype,
						   set->key->byteorder,
						   set->key->len, NULL);
			mpz_set(expr->value, p);
			root = set_elem_expr_alloc(&internal_location, expr);
			if (i->etype == EXPR_MAPPING) {
				root = mapping_expr_alloc(&internal_location,
							  root,
							  expr_get(i->right));
			}
			root->flags |= EXPR_F_INTERVAL_END;
			list_add(&root->list, &intervals);
			init->size++;
		}

		if (newelem) {
			mpz_set(p, interval_expr_key(newelem)->key->value);
			if (set->key->byteorder == BYTEORDER_HOST_ENDIAN)
				mpz_switch_byteorder(p, set->key->len / BITS_PER_BYTE);

			if (!(set->flags & NFT_SET_ANONYMOUS) ||
			    mpz_cmp(p, elem->key->left->value) != 0)
				list_add_tail(&newelem->list, &intervals);
			else
				expr_free(newelem);
		}
		newelem = NULL;

		if (mpz_scan0(elem->key->right->value, 0) != set->key->len) {
			mpz_add_ui(p, elem->key->right->value, 1);
			expr = constant_expr_alloc(&elem->key->location, set->key->dtype,
						   set->key->byteorder, set->key->len,
						   NULL);
			mpz_set(expr->value, p);
			if (set->key->byteorder == BYTEORDER_HOST_ENDIAN)
				mpz_switch_byteorder(expr->value, set->key->len / BITS_PER_BYTE);

			newelem = set_elem_expr_alloc(&internal_location, expr);
			if (i->etype == EXPR_MAPPING) {
				newelem = mapping_expr_alloc(&internal_location,
							     newelem,
							     expr_get(i->right));
			}
			newelem->flags |= EXPR_F_INTERVAL_END;
		} else {
			flags = NFTNL_SET_ELEM_F_INTERVAL_OPEN;
		}

		expr = constant_expr_alloc(&elem->key->location, set->key->dtype,
					   set->key->byteorder, set->key->len, NULL);

		mpz_set(expr->value, elem->key->left->value);
		if (set->key->byteorder == BYTEORDER_HOST_ENDIAN)
			mpz_switch_byteorder(expr->value, set->key->len / BITS_PER_BYTE);

		expr_free(elem->key);
		elem->key = expr;
		i->elem_flags |= flags;
		init->size++;
		list_move_tail(&i->list, &intervals);

		prev = i;
	}

	if (newelem)
		list_add_tail(&newelem->list, &intervals);

	list_splice_init(&intervals, &init->expressions);

	mpz_clear(p);
	mpz_clear(q);

	return 0;
}
