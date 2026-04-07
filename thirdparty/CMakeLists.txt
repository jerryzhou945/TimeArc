add_subdirectory(sqlite3)
add_subdirectory(parson)

set(TIME_ARC_THIRDPARTY_LIBS
	time-arc-sqlite3
	time-arc-parson
	PARENT_SCOPE
)
