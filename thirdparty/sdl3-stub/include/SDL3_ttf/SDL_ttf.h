// thirdparty/sdl3-stub/include/SDL3_ttf/SDL_ttf.h
//
// Headless stand-in for the real SDL3_ttf <SDL3_ttf/SDL_ttf.h>. Only the
// symbols referenced by src/builtins/gui.cpp are declared.
#pragma once

#include <SDL3/SDL.h>

#ifdef __cplusplus
extern "C" {
#endif

struct TTF_Font;

bool TTF_Init(void);
void TTF_Quit(void);

TTF_Font* TTF_OpenFont(const char* file, float ptsize);
void TTF_CloseFont(TTF_Font* font);

typedef Uint32 TTF_FontStyleFlags;
#define TTF_STYLE_NORMAL        0x00u
#define TTF_STYLE_BOLD          0x01u
#define TTF_STYLE_ITALIC        0x02u
#define TTF_STYLE_UNDERLINE     0x04u
#define TTF_STYLE_STRIKETHROUGH 0x08u

void TTF_SetFontStyle(TTF_Font* font, TTF_FontStyleFlags style);
TTF_FontStyleFlags TTF_GetFontStyle(TTF_Font* font);

// text_len==0 means "use strlen(text)" in the real API; the stub honours that.
SDL_Surface* TTF_RenderText_Blended(TTF_Font* font, const char* text, size_t text_len,
                                     SDL_Color fg);

bool TTF_GetStringSize(TTF_Font* font, const char* text, size_t text_len,
                        int* w, int* h);

#ifdef __cplusplus
}
#endif
