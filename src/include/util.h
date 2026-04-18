// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SRC_INCLUDE_UTIL_H
#define TIMEARC_SRC_INCLUDE_UTIL_H

#define TA_MAX_PATH_BYTES 4096
#define TA_MAX_TITLE_BYTES 512
#define TA_MAX_NAME_BYTES 256

#if !defined(__cplusplus)
#include <stddef.h>

// TA_CONTAINER_OF - cast a member of a structure out to the container.
// This implementation drops the 'const' qualifier from the pointer type.
#define TA_CONTAINER_OF(ptr, type, member) \
  ((type*)((char*)(1 ? (ptr) : &((type*)0)->member) - offsetof(type, member)))

// Same as TA_CONTAINER_OF but preserves the 'const' qualifier.
// Always use this macro instead of TA_CONTAINER_OF when possible.
#define TA_CONTAINER(ptr, type, member, member_type)                       \
  _Generic((ptr),                                                          \
      const member_type*: (const type*)TA_CONTAINER_OF(ptr, type, member), \
      member_type*: (type*)TA_CONTAINER_OF(ptr, type, member))

// ListHead - a simple doubly linked list head structure.
typedef struct ListHead {
  struct ListHead* next;
  struct ListHead* prev;
} ListHead;

#endif  // !defined(__cplusplus)

#endif  // TIMEARC_SRC_INCLUDE_UTIL_H
