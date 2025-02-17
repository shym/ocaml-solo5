#ifndef _SYS_TIME_H
#define _SYS_TIME_H

typedef long time_t;
typedef long suseconds_t;
struct timeval {
    time_t tv_sec;
    suseconds_t tv_usec;
};
struct timezone {
    int tz_minuteswest;
    int tz_dsttime;
};
struct timespec {
    time_t tv_sec;
    long tv_nsec;
};
int gettimeofday(struct timeval *tv, struct timezone *tz);

#endif
