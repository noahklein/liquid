package ngui

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

TextInput :: struct {
    buf: strings.Builder,
}

TextAlign :: enum {
    Left,
    Center,
    Right,
}

text :: proc($format: string, args: ..any, color := DARK_TEXT_COLOR, align := TextAlign.Left) {
    rect := flex_rect()

    text := fmt.ctprintf(format, ..args)
    text_rect(rect, text, color, align)
}

text_rect :: proc(rect: rl.Rectangle, text: cstring, color := DARK_TEXT_COLOR, align := TextAlign.Left) {
    y := rect.y + (rect.height / 2) - (f32(FONT) / 2)

    x : f32
    switch align {
    case .Left:   x = rect.x
    case .Center: x = rect.x + (rect.width / 2) - f32(rl.MeasureText(text, FONT)) / 2
    case .Right:  x = (rect.x + rect.width) - f32(rl.MeasureText(text, FONT))
    }

    rl.DrawText(text, i32(x), i32(y), FONT, color)
}

input :: proc(text: ^string, $label: cstring) {
    rect := flex_rect()
    input_rect(rect, text, label)
}

input_rect :: proc(rect: rl.Rectangle, text: ^string, label: cstring) {
    label_box, input_box := label_split_rect(rect, label)
    key := fmt.ctprintf("%s#input", label)
    active := state.active_input == key

    // Initialize text input.
    if key not_in state.text_inputs {
        state.text_inputs[key] = TextInput{
            buf = strings.builder_make(0, 64),
        }
    }
    input := &state.text_inputs[key]

    hover := hovered(rect)
    if !active && hover && rl.IsMouseButtonPressed(.LEFT) {
        state.active_input = key

        strings.builder_reset(&input.buf)

        for char in text^ {
            fmt.sbprint(&input.buf, char)
        }
    }

    if active {
        // Lose focus when you click away.
        if !hover && rl.IsMouseButtonPressed(.LEFT) {
            state.active_input = nil
            return
        }

        // Get keyboard input.
        for char := rl.GetCharPressed(); char != 0; char = rl.GetCharPressed() {
            state.last_keypress_time = rl.GetTime()
            strings.write_rune(&input.buf, char)
        }

        // Backspace to delete.
        if strings.builder_len(input.buf) > 0 && rl.IsKeyPressed(.BACKSPACE) {
            strings.pop_rune(&input.buf) // Always delete one character.

            // Ctrl+Backspace deletes entire words.
            if rl.IsKeyDown(.LEFT_CONTROL) {
                for strings.builder_len(input.buf) > 0 {
                    c, _ := strings.pop_rune(&input.buf)

                    switch c {
                    // Stop characters divide words.
                    case ' ', '-' ,'_': return
                    case:
                    }
                }
            }
        }
        // Ctrl+U clears whole buffer like UNIX terminals.
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.U) {
            strings.builder_reset(&input.buf)
        }
    }

    text_rect(label_box, label)
    rl.DrawRectangleRec(input_box, input_color(hover, active))

    text^ = strings.to_string(input.buf)
    cstr := strings.clone_to_cstring(text^, context.temp_allocator)
    text_box := padding(input_box, {INPUT_PAD, INPUT_PAD})
    text_rect(text_box, cstr, color = TEXT_COLOR)

    // Cursor
    if active {
        CURSOR_HEIGHT :: FONT + 1
        cursor_rect := rl.Rectangle{
            text_box.x + f32(rl.MeasureText(cstr, FONT) + 2),
            text_box.y + text_box.height / 2 - CURSOR_HEIGHT / 2,
            INPUT_CURSOR_WIDTH,
            CURSOR_HEIGHT,
        }
        rl.DrawRectangleRec(cursor_rect, cursor_color())
    }
}