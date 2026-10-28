shader_type canvas_item;
varying vec4 canvas_tint;
void vertex() {
    canvas_tint = COLOR;
}
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    float key = min(pixel.r, pixel.b) - pixel.g;
    float keep = 1.0 - smoothstep(0.20, 0.58, key);
    float spill = max(0.0, min(pixel.r, pixel.b) - pixel.g);
    pixel.r = max(0.0, pixel.r - spill * 0.8);
    pixel.b = max(0.0, pixel.b - spill * 0.8);
    COLOR = vec4(pixel.rgb * canvas_tint.rgb, pixel.a * keep * canvas_tint.a);
}
