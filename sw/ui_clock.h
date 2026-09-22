#ifndef UI_CLOCK_H
#define UI_CLOCK_H

// The parts that never change: the title bar, the rule under it and the foot.
// Kept out of the per-second redraw because nothing in them moves.
void ui_draw_frame(void);

void ui_show_time(const unsigned char *time);

// Drawn in place of the time when the registers do not hold valid BCD. Showing
// the digits anyway would present a fault as a reading.
void ui_show_unset(void);

#endif
