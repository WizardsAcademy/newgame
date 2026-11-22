#!/usr/bin/env python3
"""Update Player.tscn (Behemoth), Bahman.tscn (Knight), and Pari.tscn (Sylvara)
to match Velmira's exact `Shabnam.tscn` pipeline:
  - 32-frame (8x4 @ 224x224 = 1792x896) reference-extracted sprite sheets
  - `Visuals.texture_filter = 4` (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`)
  - `Visuals.position = Vector2(0, -3)` and `Visuals.scale = Vector2(0.165, 0.165)`
  - `Visuals/Shadow` (`slime_shadow.png`) at `position = Vector2(0, 89)`
  - Calm multi-frame 4-directional idles, full 4-frame walks, multi-frame
    signature attacks/dashes, and 3-stage hurt -> kneel -> fallen `die`!
"""
from __future__ import annotations

CELL = 224
COLS = 8
TOTAL_FRAMES = 32


def atlas_blocks() -> str:
    blocks = []
    for f in range(TOTAL_FRAMES):
        rx = (f % COLS) * CELL
        ry = (f // COLS) * CELL
        blocks.append(
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_f{f}"]\n'
            f'atlas = ExtResource("2_sheet")\n'
            f"region = Rect2({rx}, {ry}, {CELL}, {CELL})\n"
        )
    return "\n".join(blocks)


def anim_block(
    res_id: str,
    name: str,
    length: float,
    times: list[float],
    frames: list[int],
    loop: bool = False,
) -> str:
    t_str = ", ".join(f"{t:g}" for t in times)
    tr_str = ", ".join("1" for _ in times)
    val_str = ", ".join(f'SubResource("AtlasTexture_f{f}")' for f in frames)
    loop_line = "loop_mode = 1\n" if loop else ""
    return (
        f'[sub_resource type="Animation" id="{res_id}"]\n'
        f'resource_name = "{name}"\n'
        f"length = {length:g}\n"
        f"{loop_line}"
        f'tracks/0/type = "value"\n'
        f"tracks/0/imported = false\n"
        f"tracks/0/enabled = true\n"
        f'tracks/0/path = NodePath("Visuals:texture")\n'
        f"tracks/0/interp = 1\n"
        f"tracks/0/loop_wrap = true\n"
        f"tracks/0/keys = {{\n"
        f'"times": PackedFloat32Array({t_str}),\n'
        f'"transitions": PackedFloat32Array({tr_str}),\n'
        f'"update": 1,\n'
        f'"values": [{val_str}]\n'
        f"}}\n"
    )


def common_locomotion_anims(walk_len: float) -> list[tuple[str, str]]:
    """Calm multi-frame 4-directional idles + full 4-frame directional walks (`0..19`)."""
    q = round(walk_len / 4.0, 3)
    return [
        (
            "idle",
            anim_block(
                "Animation_idle",
                "idle",
                2.2,
                [0.0, 0.55, 1.1, 1.55, 1.85, 2.02, 2.14],
                [0, 1, 2, 1, 0, 3, 0],
                loop=True,
            ),
        ),
        (
            "idle_down",
            anim_block("Animation_idle_down", "idle_down", 1.6, [0.0, 0.8], [8, 9], loop=True),
        ),
        (
            "idle_up",
            anim_block("Animation_idle_up", "idle_up", 1.6, [0.0, 0.8], [14, 15], loop=True),
        ),
        (
            "walk",
            anim_block(
                "Animation_walk",
                "walk",
                walk_len,
                [0.0, q, round(q * 2, 3), round(q * 3, 3)],
                [4, 5, 6, 7],
                loop=True,
            ),
        ),
        (
            "walk_down",
            anim_block(
                "Animation_walk_down",
                "walk_down",
                walk_len,
                [0.0, q, round(q * 2, 3), round(q * 3, 3)],
                [10, 11, 12, 13],
                loop=True,
            ),
        ),
        (
            "walk_up",
            anim_block(
                "Animation_walk_up",
                "walk_up",
                walk_len,
                [0.0, q, round(q * 2, 3), round(q * 3, 3)],
                [16, 17, 18, 19],
                loop=True,
            ),
        ),
    ]


def build_tscn(
    uid_attr: str,
    script_path: str,
    sheet_path: str,
    body_size: tuple[int, int],
    hurtbox_size: tuple[int, int],
    hitbox_size: tuple[int, int],
    anims: list[tuple[str, str]],
    player_props: str,
    vis_scale: float,
    shadow_scale: tuple[float, float],
    dust_block: str,
    attack_x: int,
) -> str:
    load_steps = 4 + 1 + TOTAL_FRAMES + len(anims) + 1 + 2 + 1
    header = f"[gd_scene load_steps={load_steps} format=3{uid_attr}]\n\n"
    exts = (
        f'[ext_resource type="Script" path="{script_path}" id="1_script"]\n'
        f'[ext_resource type="Texture2D" path="{sheet_path}" id="2_sheet"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/textures/white_pixel.png" id="3_white"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/textures/slime_shadow.png" id="4_shadow"]\n\n'
    )
    body_sub = (
        '[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]\n'
        f"size = Vector2({body_size[0]}, {body_size[1]})\n\n"
    )
    anim_defs = "\n".join(b for _, b in anims)
    lib_entries = ",\n".join(
        f'"{name}": SubResource("Animation_{name}")' for name, _ in sorted(anims, key=lambda x: x[0])
    )
    anim_lib = (
        '\n[sub_resource type="AnimationLibrary" id="AnimationLibrary_main"]\n'
        f"_data = {{\n{lib_entries}\n}}\n\n"
    )
    shapes = (
        '[sub_resource type="RectangleShape2D" id="RectangleShape2D_hurtbox"]\n'
        f"size = Vector2({hurtbox_size[0]}, {hurtbox_size[1]})\n\n"
        '[sub_resource type="RectangleShape2D" id="RectangleShape2D_hitbox"]\n'
        f"size = Vector2({hitbox_size[0]}, {hitbox_size[1]})\n\n"
    )
    nodes = (
        '[node name="Player" type="CharacterBody2D" groups=["player"]]\n'
        "collision_layer = 2\n"
        "collision_mask = 5\n"
        "motion_mode = 1\n"
        'script = ExtResource("1_script")\n'
        f"{player_props}\n"
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\n'
        'shape = SubResource("RectangleShape2D_body")\n\n'
        '[node name="Visuals" type="Sprite2D" parent="."]\n'
        "texture_filter = 4\n"
        "position = Vector2(0, -3)\n"
        f"scale = Vector2({vis_scale:g}, {vis_scale:g})\n"
        'texture = SubResource("AtlasTexture_f0")\n\n'
        '[node name="Shadow" type="Sprite2D" parent="Visuals"]\n'
        "show_behind_parent = true\n"
        "modulate = Color(0, 0, 0, 0.38)\n"
        "position = Vector2(0, 89)\n"
        f"scale = Vector2({shadow_scale[0]:g}, {shadow_scale[1]:g})\n"
        'texture = ExtResource("4_shadow")\n\n'
        f"{dust_block}\n"
        '[node name="AnimPlayer" type="AnimationPlayer" parent="."]\n'
        'libraries = {\n"": SubResource("AnimationLibrary_main")\n}\n'
        'autoplay = "idle"\n\n'
        '[node name="AttackPoint" type="Marker2D" parent="."]\n'
        f"position = Vector2({attack_x}, 0)\n\n"
        '[node name="Hitbox" type="Area2D" parent="."]\n'
        f"position = Vector2({attack_x}, 0)\n"
        "collision_layer = 8\n"
        "collision_mask = 16\n"
        "monitoring = false\n"
        "monitorable = false\n\n"
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"]\n'
        'shape = SubResource("RectangleShape2D_hitbox")\n\n'
        '[node name="Hurtbox" type="Area2D" parent="."]\n'
        "collision_layer = 64\n"
        "collision_mask = 0\n"
        "monitoring = false\n\n"
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]\n'
        'shape = SubResource("RectangleShape2D_hurtbox")\n\n'
        '[node name="Camera2D" type="Camera2D" parent="."]\n'
        "current = true\n"
        "position_smoothing_enabled = true\n"
        "position_smoothing_speed = 5.0\n"
        "zoom = Vector2(2, 2)\n"
        "limit_left = 0\n"
        "limit_top = 0\n"
        "limit_right = 1280\n"
        "limit_bottom = 720\n\n"
        '[node name="PunchSFX" type="AudioStreamPlayer" parent="."]\n'
        'bus = &"SFX"\n\n'
        '[node name="FootstepSFX" type="AudioStreamPlayer" parent="."]\n'
        'bus = &"SFX"\n\n'
        '[node name="HurtSFX" type="AudioStreamPlayer" parent="."]\n'
        'bus = &"SFX"\n'
    )
    return header + exts + body_sub + atlas_blocks() + "\n" + anim_defs + anim_lib + shapes + nodes


def main() -> None:
    # 1. BEHEMOTH (`scenes/player/Player.tscn`)
    behemoth_anims = common_locomotion_anims(0.48) + [
        ("attack", anim_block("Animation_attack", "attack", 0.36, [0.0, 0.11, 0.28], [20, 21, 0])),
        ("attack_cross", anim_block("Animation_attack_cross", "attack_cross", 0.36, [0.0, 0.10, 0.28], [22, 23, 0])),
        ("attack_uppercut", anim_block("Animation_attack_uppercut", "attack_uppercut", 0.40, [0.0, 0.11, 0.31], [24, 25, 0])),
        ("charge", anim_block("Animation_charge", "charge", 0.22, [0.0, 0.11], [27, 28], loop=True)),
        ("hurt", anim_block("Animation_hurt", "hurt", 0.25, [0.0], [29])),
        ("die", anim_block("Animation_die", "die", 0.72, [0.0, 0.18, 0.42], [29, 30, 31])),
    ]
    behemoth_tscn = build_tscn(
        uid_attr="",
        script_path="res://scripts/player/player.gd",
        sheet_path="res://assets/textures/player_borzo.png",
        body_size=(16, 16),
        hurtbox_size=(20, 22),
        hitbox_size=(26, 20),
        anims=behemoth_anims,
        player_props=(
            'character_id = "behemoth"\n'
            'character_name = "Behemoth"\n'
            "move_speed = 92.0\n"
            "attack_duration = 0.42\n"
            "attack_damage = 18\n"
            "attack_windup = 0.14\n"
            "hitbox_active_time = 0.13\n"
            "max_health = 120\n"
            "dash_speed = 360.0\n"
            "dash_deals_damage = true\n"
            "dash_phases_enemies = true\n"
            "dash_damage = 18\n"
            "attack_point_offset_x = 16.0\n"
        ),
        vis_scale=0.165,
        shadow_scale=(3.8, 3.5),
        dust_block=(
            '[node name="Dust" type="CPUParticles2D" parent="."]\n'
            "position = Vector2(0, 10)\n"
            "emitting = false\n"
            "amount = 6\n"
            "lifetime = 0.4\n"
            "one_shot = true\n"
            "explosiveness = 0.9\n"
            "direction = Vector2(0, -1)\n"
            "spread = 60.0\n"
            "gravity = Vector2(0, -20)\n"
            "initial_velocity_min = 10.0\n"
            "initial_velocity_max = 25.0\n"
            "scale_amount_min = 1.0\n"
            "scale_amount_max = 2.0\n"
            "color = Color(1, 1, 1, 0.3)\n"
        ),
        attack_x=16,
    )
    with open("scenes/player/Player.tscn", "w", encoding="utf-8") as fh:
        fh.write(behemoth_tscn)

    # 2. KNIGHT (`scenes/player/Bahman.tscn`)
    knight_anims = common_locomotion_anims(0.54) + [
        ("attack", anim_block("Animation_attack", "attack", 0.50, [0.0, 0.14, 0.28, 0.42], [20, 21, 22, 23])),
        ("guard", anim_block("Animation_guard", "guard", 0.50, [0.0, 0.25], [24, 25], loop=True)),
        ("charge", anim_block("Animation_charge", "charge", 0.22, [0.0, 0.11], [26, 27], loop=True)),
        ("hurt", anim_block("Animation_hurt", "hurt", 0.25, [0.0], [29])),
        ("die", anim_block("Animation_die", "die", 0.75, [0.0, 0.18, 0.44], [29, 30, 31])),
    ]
    knight_tscn = build_tscn(
        uid_attr=' uid="uid://cbahmanscn001"',
        script_path="res://scripts/player/bahman.gd",
        sheet_path="res://assets/textures/player_bahman.png",
        body_size=(16, 16),
        hurtbox_size=(20, 22),
        hitbox_size=(46, 36),
        anims=knight_anims,
        player_props=(
            'character_id = "knight"\n'
            'character_name = "Knight"\n'
            "move_speed = 68.0\n"
            "attack_duration = 0.52\n"
            "attack_damage = 26\n"
            "attack_windup = 0.17\n"
            "hitbox_active_time = 0.15\n"
            "max_health = 150\n"
            "dash_speed = 310.0\n"
            "dash_deals_damage = true\n"
            "dash_phases_enemies = true\n"
            "dash_damage = 16\n"
            "attack_point_offset_x = 22.0\n"
        ),
        vis_scale=0.165,
        shadow_scale=(3.7, 3.5),
        dust_block=(
            '[node name="Dust" type="CPUParticles2D" parent="."]\n'
            "position = Vector2(0, 10)\n"
            "emitting = false\n"
            "amount = 6\n"
            "lifetime = 0.4\n"
            "one_shot = true\n"
            "explosiveness = 0.9\n"
            "direction = Vector2(0, -1)\n"
            "spread = 60.0\n"
            "gravity = Vector2(0, -20)\n"
            "initial_velocity_min = 10.0\n"
            "initial_velocity_max = 25.0\n"
            "scale_amount_min = 1.0\n"
            "scale_amount_max = 2.0\n"
            "color = Color(0.95, 0.84, 0.52, 0.35)\n"
        ),
        attack_x=22,
    )
    with open("scenes/player/Bahman.tscn", "w", encoding="utf-8") as fh:
        fh.write(knight_tscn)

    # 3. SYLVARA (`scenes/player/Pari.tscn`)
    sylvara_anims = common_locomotion_anims(0.40) + [
        ("attack", anim_block("Animation_attack", "attack", 0.24, [0.0, 0.06, 0.12, 0.18], [20, 21, 22, 23])),
        ("bow_draw", anim_block("Animation_bow_draw", "bow_draw", 0.22, [0.0, 0.11], [24, 25])),
        ("bow_charge", anim_block("Animation_bow_charge", "bow_charge", 0.28, [0.0, 0.14], [25, 26], loop=True)),
        ("bow_release", anim_block("Animation_bow_release", "bow_release", 0.22, [0.0, 0.12], [23, 0])),
        ("charge", anim_block("Animation_charge", "charge", 0.24, [0.0, 0.12], [27, 28], loop=True)),
        ("hurt", anim_block("Animation_hurt", "hurt", 0.25, [0.0], [29])),
        ("die", anim_block("Animation_die", "die", 0.72, [0.0, 0.18, 0.42], [29, 30, 31])),
    ]
    sylvara_tscn = build_tscn(
        uid_attr=' uid="uid://cpariscn00001"',
        script_path="res://scripts/player/pari.gd",
        sheet_path="res://assets/textures/player_pari.png",
        body_size=(14, 16),
        hurtbox_size=(18, 20),
        hitbox_size=(18, 14),
        anims=sylvara_anims,
        player_props=(
            'character_id = "sylvara"\n'
            'character_name = "Sylvara"\n'
            "move_speed = 124.0\n"
            "attack_duration = 0.24\n"
            "attack_damage = 15\n"
            "attack_windup = 0.08\n"
            "hitbox_active_time = 0.08\n"
            "max_health = 100\n"
            "dash_speed = 400.0\n"
            "dash_deals_damage = false\n"
            "dash_phases_enemies = true\n"
            "dash_damage = 0\n"
        ),
        vis_scale=0.165,
        shadow_scale=(3.5, 3.3),
        dust_block=(
            '[node name="Dust" type="CPUParticles2D" parent="."]\n'
            "position = Vector2(0, 10)\n"
            "emitting = false\n"
            "amount = 6\n"
            "lifetime = 0.35\n"
            "one_shot = true\n"
            "explosiveness = 0.9\n"
            "direction = Vector2(0, -1)\n"
            "spread = 60.0\n"
            "gravity = Vector2(0, -20)\n"
            "initial_velocity_min = 12.0\n"
            "initial_velocity_max = 28.0\n"
            "scale_amount_min = 1.0\n"
            "scale_amount_max = 2.0\n"
            "color = Color(0.65, 1, 0.72, 0.32)\n"
        ),
        attack_x=14,
    )
    with open("scenes/player/Pari.tscn", "w", encoding="utf-8") as fh:
        fh.write(sylvara_tscn)

    print("Updated Player.tscn, Bahman.tscn, and Pari.tscn to 32x 224x224 (matching Velmira)!")


if __name__ == "__main__":
    main()
