/* WITNESS – Cache Timing Sensor (Prime+Probe)
   If it fucking worked....
   SPDX-License-Identifier: GPL-3.0-or-later */
import std.stdio;
import std.datetime.stopwatch;
import std.conv : to;
import core.sys.posix.unistd : usleep;

ulong measure_access_ns(void* addr) {
    auto sw = StopWatch(AutoStart.no);
    sw.start();
    // volatile read
    asm { "" : : "r"(*cast(ubyte*)addr) : "memory"; }
    sw.stop();
    return sw.peek.total!"nsecs";
}

void prime_probe(void* probe_addr, int iterations = 1000) {
    writefln("[Witness] Prime+Probe on 0x%x", cast(size_t)probe_addr);
    auto timings = new ulong[iterations];
    foreach (i; 0 .. iterations) {
        asm { "" : : "r"(*cast(ubyte*)probe_addr) : "memory"; }
        usleep(10);
        timings[i] = measure_access_ns(probe_addr);
    }
    ulong sum = 0;
    foreach (t; timings) sum += t;
    double avg = cast(double)sum / iterations;
    int fast = 0, slow = 0;
    foreach (t; timings) {
        if (t < avg * 0.7) fast++;
        else if (t > avg * 1.5) slow++;
    }
    writefln("[Witness] avg=%.1fns fast=%d slow=%d (n=%d)", avg, fast, slow, iterations);
    if (fast > iterations / 10)
        writeln("[Witness] ⚠ Potential cache side-channel detected");
}

int main(string[] args) {
    writeln("[Witness] Cache Timing Sensor v3.0");
    if (args.length >= 2) {
        prime_probe(cast(void*)args[1].to!ulong(16));
    } else {
        auto buf = new ubyte[4096];
        prime_probe(buf.ptr);
    }
    return 0;
}
