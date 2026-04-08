// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SRC_INCLUDE_UTIL_H
#define TIMEARC_SRC_INCLUDE_UTIL_H

#define _TIMEARC_MAX_PATH_BYTES 4096
#define _TIMEARC_MAX_TITLE_BYTES 512
#define _TIMEARC_MAX_NAME_BYTES 256

#ifndef __cplusplus
#include <stddef.h>

// CONTAINER_OF - cast a member of a structure out to the containing structure.
// This implementation drops the 'const' qualifier from the pointer type.
#define CONTAINER_OF(ptr, type, member) \
  ((type*)((char*)(1 ? (ptr) : &((type*)0)->member) - offsetof(type, member)))

// Same as CONTAINER_OF but preserves the 'const' qualifier of the pointer type.
// Always use this macro instead of CONTAINER_OF when possible.
#define CONTAINER(ptr, type, member, member_type)                       \
  _Generic((ptr),                                                       \
      const member_type*: (const type*)CONTAINER_OF(ptr, type, member), \
      member_type*: (type*)CONTAINER_OF(ptr, type, member))

// ListHead - a simple doubly linked list head structure.
typedef struct ListHead {
  struct ListHead* next;
  struct ListHead* prev;
} ListHead;

#endif  // __cplusplus

#endif  // TIMEARC_SRC_INCLUDE_UTIL_H
