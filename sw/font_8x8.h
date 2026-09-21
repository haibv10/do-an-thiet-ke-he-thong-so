#ifndef FONT_8X8_H
#define FONT_8X8_H

#define FONT_FIRST    0x20
#define FONT_LAST     0x7e
#define FONT_SIZE     8

// Eight bytes a glyph, one byte a row, most significant bit leftmost, for
// ASCII 32 through 126 in order.
extern const unsigned char font8x8[];

#endif
