#ifndef INPUT_TOUCH_H
#define INPUT_TOUCH_H

#include "core/time.h"

#define MAX_ACTIVE_TOUCHES 2

typedef struct {
    int x;
    int y;
} touch_coords;

typedef enum {
    TOUCH_MODE_ORIGINAL = 0, // original julius touch mode
    TOUCH_MODE_TOUCHPAD = 1, // drag the pointer and tap-click like on a touchpad (default)
    TOUCH_MODE_DIRECT = 2, // pointer jumps to finger but doesn't click on tap
    TOUCH_MODE_MAX = 3
} touch_mode;

typedef enum {
    TOUCH_GESTURE_UNDECIDED = 0,
    TOUCH_GESTURE_PAN = 1,
    TOUCH_GESTURE_ZOOM = 2
} touch_gesture;

typedef enum {
    TOUCH_INPUT_FINGER = 0,
    TOUCH_INPUT_PENCIL = 1
} touch_input_type;

typedef struct {
    int in_use;
    int has_started;
    int has_moved;
    int has_ended;
    int long_press_handled;
    touch_input_type input_type;
    touch_coords start_point;
    touch_coords current_point;
    touch_coords previous_frame_point;
    touch_coords frame_movement;
    touch_coords last_movement;
    time_millis start_time;
    time_millis last_change_time;
} touch;

const touch *touch_get_earliest(void);
const touch *touch_get_latest(void);

int touch_not_click(const touch *t);
int touch_was_click(const touch *t);
int touch_was_double_click(const touch *t);
int touch_was_two_finger_tap(void);
int touch_poll_long_press(void);
void touch_consume_current_gesture(void);
touch_gesture touch_get_two_finger_gesture(void);
int touch_is_navigation_only(const touch *t);

int touch_is_scroll(void);
int touch_get_scroll(void);

void reset_touches(int reset_old_touch);

int touch_create(touch_coords start_coords, time_millis start_time);
int touch_create_with_input(touch_coords start_coords, time_millis start_time, touch_input_type input_type);
void touch_move(int index, touch_coords current_coords, time_millis current_time);
void touch_end(int index, time_millis current_time);
int touch_in_use(int index);

int touch_to_mouse(void);

void touch_set_mode(touch_mode mode);
void touch_cycle_mode(void);
void touch_set_pencil_mode(int enabled);
int touch_pencil_mode(void);

#endif // INPUT_TOUCH_H
