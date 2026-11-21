#!/usr/bin/env python3
"""Update Player.tscn (Behemoth), Bahman.tscn (Knight), and Pari.tscn (Sylvara)
to use the redesigned 24-frame (8x3 @ 128x128) dark-fantasy sprite sheets,
calm natural multi-frame 4-directional idles, 4-frame grounded walks,
collapse `die` animations, and elliptical `slime_shadow.png` foot shadows.
"""
from __future__ import annotations

CELL = 128
COLS = 8
TOTAL_FRAMES = 24


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
    """Calm, natural multi-frame idles (`idle`, `idle_down`, `idle_up`) + 4-beat walks!"""
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
            anim_block("Animation_idle_up", "idle_up", 1.6, [0.0, 0.8], [12, 13], loop=True),
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
                [10, 8, 11, 9],
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
                [14, 12, 15, 13],
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
    # Count exact load_steps: 4 ext_resources + 1 body shape + 24 atlas + len(anims) + 1 anim_lib + 2 shapes
    load_steps = 4 + 1 + TOTAL_FRAMES + len(anims) + 1 + 2
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
        "texture_filter = 1\n"
        "position = Vector2(0, -3)\n"
        f"scale = Vector2({vis_scale:g}, {vis_scale:g})\n"
        'texture = SubResource("AtlasTexture_f0")\n\n'
        '[node name="Shadow" type="Sprite2D" parent="Visuals"]\n'
        "show_behind_parent = true\n"
        "modulate = Color(0, 0, 0, 0.38)\n"
        "position = Vector2(0, 44)\n"
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
        ("attack", anim_block("Animation_attack", "attack", 0.34, [0.0, 0.10, 0.27], [16, 17, 0])),
        ("attack_cross", anim_block("Animation_attack_cross", "attack_cross", 0.34, [0.0, 0.09, 0.27], [16, 18, 0])),
        ("attack_uppercut", anim_block("Animation_attack_uppercut", "attack_uppercut", 0.38, [0.0, 0.10, 0.30], [16, 19, 0])),
        ("charge", anim_block("Animation_charge", "charge", 0.20, [0.0], [20], loop=True)),
        ("hurt", anim_block("Animation_hurt", "hurt", 0.25, [0.0], [21])),
        ("die", anim_block("Animation_die", "die", 0.72, [0.0, 0.18, 0.42], [21, 22, 23])),
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
        vis_scale=0.335,
        shadow_scale=(1.95, 1.80),
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
        ("attack", anim_block("Animation_attack", "attack", 0.50, [0.0, 0.15, 0.30, 0.44], [16, 17, 18, 0])),
        ("guard", anim_block("Animation_guard", "guard", 0.30, [0.0], [19], loop=True)),
        ("charge", anim_block("Animation_charge", "charge", 0.20, [0.0], [20], loop=True)),
        ("hurt", anim_block("Animation_hurt", "hurt", 0.25, [0.0], [21])),
        ("die", anim_block("Animation_die", "die", 0.75, [0.0, 0.18, 0.44], [21, 22, 23])),
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
        vis_scale=0.33,
        shadow_scale=(1.90, 1.75),
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
            "color = Color(0.82, 0.88, 0.98, 0.35)\n"
        ),
        attack_x=22,
    )
    with open("scenes/player/Bahman.tscn", "w", encoding="utf-8") as fh:
        fh.write(knight_tscn)

    # 3. SYLVARA (`scenes/player/Pari.tscn`)
    sylvara_anims = common_locomotion_anims(0.40) + [
        ("attack", anim_block("Animation_attack", "attack", 0.24, [0.0, 0.09, 0.17], [16, 18, 19])),
        ("bow_draw", anim_block("Animation_bow_draw", "bow_draw", 0.20, [0.0], [16])),
        ("bow_charge", anim_block("Animation_bow_charge", "bow_charge", 0.20, [0.0], [17], loop=True)),
        ("bow_release", anim_block("Animation_bow_release", "bow_release", 0.24, [0.0, 0.11, 0.20], [18, 19, 0])),
        ("charge", anim_block("Animation_charge", "charge", 0.20, [0.0], [20], loop=True)),
        ("hurt", anim_block("Animation_hurt", "hurt", 0.25, [0.0], [21])),
        ("die", anim_block("Animation_die", "die", 0.72, [0.0, 0.18, 0.42], [21, 22, 23])),
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
        vis_scale=0.33,
        shadow_scale=(1.75, 1.65),
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

    print("Updated Player.tscn, Bahman.tscn, and Pari.tscn cleanly!")


if __name__ == "__main__":
    main()
