// maxrversion.h for MaXtreme GDExtension
#ifndef maxrversionH
#define maxrversionH

#include <string>

#define PACKAGE_NAME "MaXtreme"
#define PACKAGE_VERSION "0.1.0"

#ifndef GIT_DESC
#define GIT_DESC "unknown"
#endif

#define PACKAGE_REV "GIT Hash " GIT_DESC
#define MAX_BUILD_DATE ((std::string) __DATE__ + " " + __TIME__)

inline void logMAXRVersion() {}
inline void logNlohmannVersion() {}

#endif
