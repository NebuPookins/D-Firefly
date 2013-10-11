/**
 * Fireflies demo program.
 *
 * The intent of this program is to illustrate how to program using D and
 * Allegro5.
 *
 * Authors: Nebu Pookins (nebupookins@gmail.com)
 * Date: 2013-10-11
 * License: MIT License http://opensource.org/licenses/MIT
 * Copyright: Nebu Pookins 2013
 */
module firefly;

pragma(lib, "dallegro5");
pragma(lib, "allegro");
pragma(lib, "allegro_primitives");

import allegro5.allegro;
import allegro5.allegro_primitives;
import std.exception;

immutable FPS = 60.0;
immutable NUM_FLIES = 2000;
immutable WIDTH = 640;
immutable HEIGHT = 480;
immutable MAX_VEL = 5;
immutable ACCEL = 0.1;

/**
 * Ensures a given value is between two other values.
 */
@safe pure T clamp(T)(in T minVal, in T val, in T maxVal)
out(result) {
	assert(minVal <= result, "Bug in clamp: result was less than minVal.");
	assert(result <= maxVal, "Bug in clamp: result was greater than maxVal.");
	assert(
		result == minVal || result == val || result == maxVal,
		"Bug in clamp: result was not minVal, val, nor maxVal."
	);
} body {
	enforce(minVal <= maxVal, "minVal must be less than maxVel.");
	import std.algorithm;
	return max(minVal, min(val, maxVal));
}
///
unittest {
	assert(clamp(0,1,2) == 1);
	assert(clamp(1,1,2) == 1);
	assert(clamp(1,1,1) == 1);
	assert(clamp(2,1,3) == 2);
	assert(clamp(2,4,3) == 3);
}

final class Firefly {
	import std.random;

	float x;
	float y;
	float xVel;
	float yVel;
	immutable(ALLEGRO_COLOR) color;

	invariant() {
		assert(
			-MAX_VEL <= this.xVel && this.xVel <= MAX_VEL,
			"Bug in Firefly: xVel is outside of range -MAX_VEL to MAX_VEL."
		);
		assert(-MAX_VEL <= this.yVel && this.yVel <= MAX_VEL,
			"Bug in Firefly: yVel is outside of range -MAX_VEL to MAX_VEL."
		);
	}

	this(in ALLEGRO_COLOR color) {
		this.x = uniform(0, WIDTH);
		this.y = uniform(0, WIDTH);
		this.xVel = uniform!("[]", float, float)(-MAX_VEL, MAX_VEL);
		this.yVel = uniform!("[]", float, float)(-MAX_VEL, MAX_VEL);
		this.color = color;
	}

	void draw() {
		al_draw_line(
			this.x, this.y,
			this.x + this.xVel, this.y + this.yVel,
			this.color,
			1
		);
	}

	void update(in Firefly heroFly) {
		enforce(heroFly != this);
		this.x += this.xVel;
		this.y += this.yVel;
		immutable float adjustVelocity(
				in float curPos,
				in int maxPos,
				in float curVel,
				in float* targetPos
		) {
			@safe pure float velClamp(in float vel) {
				return clamp!(float)(-MAX_VEL, vel, MAX_VEL);
			}
			if (curPos < 0) {
				return velClamp(curVel + ACCEL);
			} else if (curPos > maxPos) {
				return velClamp(curVel - ACCEL);
			} else {
				if (targetPos is null) {
					return velClamp(curVel + ACCEL * uniform!("[]", int, int)(-1, 1));
				} else if (*targetPos < curPos) {
					return velClamp(curVel - ACCEL);
				} else if (*targetPos > curPos) {
					return velClamp(curVel + ACCEL);
				} else {
					return velClamp(curVel + ACCEL * uniform!("[]", int, int)(-1, 1));
				}
			}
		}
		this.xVel = adjustVelocity(this.x, WIDTH, this.xVel, heroFly is null ? null : &heroFly.x);
		this.yVel = adjustVelocity(this.y, HEIGHT, this.yVel, heroFly is null ? null : &heroFly.y);
	}
}

immutable int main(char[][] args) {
	return al_run_allegro({
		import std.stdio;
		enforce(al_init(), "Failed to initialize Allegro.");
		enforce(
			al_init_primitives_addon(),
			"Failed to initialize Allegro Primitives Add-on."
		);
		enforce(al_install_keyboard(), "Failed to initialize keyboard.");
		enforce(al_install_mouse(), "Failed to initialize mouse.");
		al_set_new_display_flags(ALLEGRO_WINDOWED | ALLEGRO_RESIZABLE);
		al_set_new_display_option(ALLEGRO_DISPLAY_OPTIONS.ALLEGRO_SINGLE_BUFFER, 1, ALLEGRO_SUGGEST);
		al_set_new_display_option(ALLEGRO_DISPLAY_OPTIONS.ALLEGRO_UPDATE_DISPLAY_REGION, 0, ALLEGRO_SUGGEST);
		auto display = enforce(
			al_create_display(WIDTH, HEIGHT),
			"Failed to create display."
		);
		scope(exit) al_destroy_display(display);
		auto buffer = al_create_bitmap(WIDTH, HEIGHT);
		scope(exit) al_destroy_bitmap(buffer);

		auto timer = enforce(al_create_timer(1.0 / FPS), "Failed to create timer.");
		scope(exit) al_destroy_timer(timer);
		auto eventQueue = enforce(
			al_create_event_queue(),
			"Failed to create event queue."
		);
		scope(exit) al_destroy_event_queue(eventQueue);

		al_register_event_source(eventQueue, al_get_display_event_source(display));
		al_register_event_source(eventQueue, al_get_timer_event_source(timer));
		al_register_event_source(eventQueue, al_get_keyboard_event_source());
		al_register_event_source(eventQueue, al_get_mouse_event_source());

		al_start_timer(timer);

		immutable bgColor = al_map_rgb(0,0,0);
		immutable fireflyColor = al_map_rgb(255,0,0);
		immutable heroColor = al_map_rgb(255,255,0);
		immutable debugColor = al_map_rgb(255,255,255);
		auto fireflies = new Firefly[NUM_FLIES];
		foreach (i; 0..NUM_FLIES) {
			fireflies[i] = new Firefly(fireflyColor);
		}
		auto heroFly = new Firefly(heroColor);
		bool exit = false;
		while(!exit) {
			ALLEGRO_EVENT event;
			al_wait_for_event(eventQueue, &event);
			switch (event.type) {
				case ALLEGRO_EVENT_TIMER:
					float actualWidth = al_get_display_width(display);
					float actualHeight = al_get_display_height(display);
					float xScaling = actualWidth / WIDTH;
					float yScaling = actualHeight / HEIGHT;
					al_set_target_bitmap(buffer);
					al_clear_to_color(bgColor);
					al_draw_line(0,0,WIDTH,HEIGHT,debugColor,1);
					foreach(i; 0..NUM_FLIES) {
						fireflies[i].draw();
						fireflies[i].update(heroFly);
					}
					heroFly.draw();
					heroFly.update(null);
					al_set_target_backbuffer(display);
					al_clear_to_color(al_map_rgb(0, 0, 0));
					al_draw_scaled_bitmap(
						buffer,
						0, 0, WIDTH, HEIGHT,
						0, 0, actualWidth, actualHeight,
						0
					);
					al_flip_display();
					break;
				case ALLEGRO_EVENT_DISPLAY_RESIZE:
					al_acknowledge_resize(display);
					break;
				case ALLEGRO_EVENT_DISPLAY_CLOSE:
				case ALLEGRO_EVENT_KEY_DOWN:
				case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
					exit = true;
					break;
				default:
					//Do nothing.
					break;
			}
		}
		return 0;
	});
}
