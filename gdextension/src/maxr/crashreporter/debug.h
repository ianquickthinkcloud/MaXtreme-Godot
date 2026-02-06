// crashreporter/debug.h stub for MaXtreme GDExtension
// No crash reporting in the Godot build - all macros are no-ops.
#ifndef MAXTREME_CRASHREPORTER_DEBUG_STUB_H
#define MAXTREME_CRASHREPORTER_DEBUG_STUB_H

#define CR_ENABLE_CRASH_RPT_CURRENT_THREAD() do {} while(0)

inline void CR_EMULATE_CRASH() {}
inline void CR_INIT_CRASHREPORTING() {}

#endif // MAXTREME_CRASHREPORTER_DEBUG_STUB_H
