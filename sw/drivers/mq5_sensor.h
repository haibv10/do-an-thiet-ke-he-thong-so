#ifndef MQ5_SENSOR_H
#define MQ5_SENSOR_H

#define MQ5_LEVEL_CLEAN   0
#define MQ5_LEVEL_WARN    1
#define MQ5_LEVEL_DANGER  2

#define MQ5_WARN_MV       1500
#define MQ5_DANGER_MV     2500

int mq5_read_mv(unsigned int *mv);

unsigned int mq5_raw_to_mv(int raw);

unsigned int mq5_level_of(unsigned int mv);

#endif
