#include "app_identity.h"

#include <string.h>

int timearc_app_identity_equal(const AppInfo* left, const AppInfo* right) {
  return left != NULL && right != NULL &&
         left->process_id == right->process_id &&
         strcmp(left->exec_path, right->exec_path) == 0 &&
         strcmp(left->window_title, right->window_title) == 0 &&
         strcmp(left->app_name, right->app_name) == 0 &&
         strcmp(left->display_name, right->display_name) == 0;
}
