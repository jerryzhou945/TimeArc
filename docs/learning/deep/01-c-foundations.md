# 01 · C 语言：读懂原生服务 / C Foundations for the Native Collector

## 1. C 在 TimeArc 中做什么

Windows 的 `time-arc-service` 用 C11 编写。它靠近 Win32、WASAPI、COM 和 SQLite C API，职责是采样与写盘，不创建 Qt 对象、不加载 QML。

如果你来自 Python/JavaScript，先记住：C 源码会提前编译成机器代码；编译器必须在使用函数前知道它的声明；内存、缓冲区和系统资源通常要显式管理。

## 2. `.h` 与 `.c`

头文件 `.h` 像菜单：告诉别的文件“有哪些类型和函数”。实现文件 `.c` 像厨房：真正完成工作。

当前 `src/service/windows/platform/idle_win.h` 的核心声明是：

```c
uint32_t timearc_win_idle_delta_ms(uint32_t now_tick,
                                   uint32_t last_input_tick);
int64_t timearc_win_get_idle_ms(void);
int timearc_win_is_idle(int64_t idle_threshold_ms);
```

逐项解释：

- `uint32_t` 是固定 32 位无符号整数，适合 Windows tick 差值。
- `int64_t` 是固定 64 位有符号整数，能安全容纳较大的毫秒数。
- `(void)` 明确表示不接收参数。
- 声明以分号结束；实现会有 `{ ... }`。

## 3. Include guard

头文件会被多个源文件包含。为了防止同一声明被文本展开多次，使用：

```c
#ifndef TIMEARC_IDLE_WIN_H
#define TIMEARC_IDLE_WIN_H
/* declarations */
#endif
```

预处理器在真正编译前执行这些 `#` 指令。第二次 include 时宏已经定义，中间内容被跳过。

## 4. 结构体：把一次观察打包

`src/service/shared/app_info.h` 定义：

```c
typedef struct AppInfo {
  char exec_path[TA_MAX_PATH_BYTES];
  char window_title[TA_MAX_TITLE_BYTES];
  char app_name[TA_MAX_NAME_BYTES];
  char display_name[TA_MAX_NAME_BYTES];
  uint32_t process_id;
  time_t timestamp;
  uint64_t active_time;
  bool active_status;
} AppInfo;
```

`struct` 把相关字段组成新类型；`typedef` 让后续可以写 `AppInfo app;`，不用每次写 `struct AppInfo`。

这里的字符数组直接嵌在结构体中。优点是结构大小固定、复制简单、没有单独分配；代价是必须始终检查容量。

## 5. C 字符串为什么危险

C 字符串是以 `\0` 结束的 `char` 数组。数组不会自动扩容，也不会自动阻止越界。

```c
char title[TA_MAX_TITLE_BYTES];
```

如果写入长度等于整个容量，却没有给 `\0` 留一个字节，后续 `strlen` 会继续读到别的内存。TimeArc 因此集中定义 `TA_MAX_*` 上限，并在复制前检查 `len + 1 <= capacity`。

## 6. 指针：内存地址

```c
int timearc_win_get_active_app(AppInfo* out_app);
```

`AppInfo*` 是“指向 AppInfo 的地址”。调用者先准备对象：

```c
AppInfo app;
memset(&app, 0, sizeof(app));
int rc = timearc_win_get_active_app(&app);
```

- `&app` 取得对象地址。
- 函数通过 `out_app->exec_path` 修改调用者对象。
- 返回值空出来表示成功或失败。
- `memset(..., 0, ...)` 让所有数组开头为 `\0`、数字为 0，避免读取未初始化垃圾值。

这叫 output parameter pattern。

## 7. `const` 表示只读承诺

```c
int timearc_usage_tracker_run(const TimeArcUsageTrackerConfig* config);
```

这里传地址避免复制结构体，`const` 又保证函数不通过该地址修改配置。它不是“绝对安全”，但让编译器阻止大多数误写。

## 8. `NULL` 检查

指针可能不指向有效对象：

```c
if (state == NULL || sample == NULL) {
  return 0;
}
```

直接使用空指针通常会导致 access violation。公共 C 函数在解引用前先验证参数，是服务稳定性的第一层防线。

## 9. 返回码而不是异常

C 没有 C++/Java 异常。TimeArc 常用：

- `0`：成功。
- `-1` 或其他非零：失败。
- 某些 predicate 用 `1` 表示 true、`0` 表示 false。

阅读时必须结合函数注释判断，不能机械认为所有非零都是错误。例如 `timearc_foreground_state_step()` 返回 1 表示“导出了一条关闭会话”。

## 10. `static` 的两种常见意义

文件作用域函数：

```c
static int64_t unix_time_sec(void) { ... }
```

表示只在当前 `.c` 可见，相当于私有 helper，避免与其他文件同名函数冲突。

文件作用域变量：

```c
static volatile LONG g_stop_requested = 0;
```

表示程序运行期间一直存在，但只由当前实现文件访问。

## 11. 条件编译

`database_path.c` 同时支持多平台：

```c
#ifdef _WIN32
  const char separator = '\\';
#else
  const char separator = '/';
#endif
```

未选择的分支根本不参与本次编译。这与运行时 `if` 不同，也解释了 shared C 文件如何避免同时依赖 Windows 和 Unix API。

## 12. 资源必须成对释放

Windows HANDLE 要 `CloseHandle`；COM interface 要 `Release`；SQLite statement 要 `sqlite3_finalize`；数据库连接要 `sqlite3_close`。

服务代码常用单一 cleanup 路径，因为函数中途失败也必须释放已经取得的前半部分资源。面试可以称为 deterministic cleanup。

## 13. 从一行代码读出完整意图

```c
if (update_apps(...) != 0) {
  return;
}
update_frontmost(...);
```

它不仅表示“先后调用”。它表达了存储不变量：应用身份写失败时，不继续写一条可能无法正确关联的 session。

## English vocabulary

header, source file, declaration, definition, include guard, structure, pointer, output parameter, fixed-size buffer, null terminator, conditional compilation, return code, cleanup path, resource ownership.

## Interview sentence

“The Windows collector uses C11 and fixed-size observation structures. I rely on explicit output parameters, checked buffers, return codes, and deterministic resource cleanup because the service sits directly on native Windows and SQLite APIs.”

## 练习

1. `const AppInfo* app` 与 `AppInfo* const app` 有何区别？前者不能改指向内容；后者不能改指针本身。
2. 为什么 `sizeof(array)` 在数组仍是数组时有用，传进函数后常失效？因为参数会退化为指针，`sizeof` 只剩地址大小。
3. 找出 `usage_tracker.c` 中三个 `memset`，说明每个在防什么未初始化状态。
