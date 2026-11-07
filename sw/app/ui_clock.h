#ifndef UI_CLOCK_H
#define UI_CLOCK_H

void ui_draw_frame(void);

void ui_show_time(const unsigned char *time);

void ui_show_unset(void);

void ui_show_environment(unsigned char temperature, unsigned char humidity);
void ui_show_environment_fault(void);
void ui_show_gas(unsigned int mv, unsigned int level);
void ui_show_gas_fault(void);

#endif
