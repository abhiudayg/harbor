import Darwin

enum ProcessMemory {
    static func peakResidentBytes() -> UInt64? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            return nil
        }
        return UInt64(usage.ru_maxrss)
    }
}
