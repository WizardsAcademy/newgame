#!/usr/bin/env python
"""Generate Velmira's 8-frame 96x96 white-haired gothic vampire sheet.

Rebuilt from the 96x96 gothic vampire base with:
  - Moonlit silver-white flowing hair (preserving her crimson rose, ruby eyes,
    porcelain skin, pointed ears, and black-crimson gothic dress),
  - Graceful flared-sleeve Blood Whip cast animation,
  - Expressive Hurt recoil pose + Bat-Mist dissolve pose.

Writes:
    assets/textures/player_shabnam.png   768 x 96 (8 frames of 96x96)
    assets/textures/velmira_ambient.png  288 x 96 (3 ambient frames: bat + sparkles)
    docs/images/velmira_preview.png      review sheet

SHEET LAYOUT  (matches scenes/player/Shabnam.tscn):
    frame 0 : idle
    frame 1 : walk A
    frame 2 : walk B
    frame 3 : cast gather   (blazing ruby eyes + floating liquid blood orb)
    frame 4 : cast whip     (flared gothic sleeve + curved liquid blood whip)
    frame 5 : idle blink
    frame 6 : hurt          (wincing recoil + fang grimace)
    frame 7 : bat dissolve  (crimson mist + bat silhouette form)
"""

import math
from PIL import Image, ImageDraw

FRAME = 96
FRAMES = 8

BASE_PAL = [
    (47, 31, 50, 255),
    (27, 18, 29, 255),
    (8, 5, 8, 255),
    (37, 25, 40, 255),
    (15, 9, 16, 255),
    (23, 13, 22, 255),
    (99, 15, 41, 255),
    (42, 28, 45, 255),
    (233, 197, 204, 255),
    (60, 7, 25, 255),
    (33, 4, 15, 255),
    (70, 49, 67, 255),
    (73, 10, 31, 255),
    (166, 128, 142, 255),
    (87, 13, 36, 255),
    (38, 8, 20, 255),
    (54, 24, 43, 255),
]

EXTRA = {
    "iris_hi": (250, 86, 118, 255),
    "blood": (205, 24, 56, 255),
    "blood_hi": (252, 98, 128, 255),
    "white": (255, 255, 255, 255),
}

# Moonlit pearl-white / silver hair ramp replacing dark plum hair tones
WHITE_HAIR_MAP = {
    (70, 49, 67): (252, 250, 255, 255),   # L -> pure pearl highlight
    (47, 31, 50): (235, 232, 246, 255),   # A -> bright moonlit white
    (42, 28, 45): (218, 213, 234, 255),   # H -> silken silver
    (37, 25, 40): (198, 191, 218, 255),   # D -> cool silver-lavender mid
    (27, 18, 29): (168, 158, 192, 255),   # B -> soft silver shadow
    (23, 13, 22): (136, 126, 162, 255),   # F -> deep slate-silver lock crease
    (54, 24, 43): (208, 198, 224, 255),   # Q -> subtle warm silver
}

SYMS = "ABCDEFGHIJKLMNOPQ"

DECOR_SPARK_TOP = (74, 11, [
    "..PP..",
    "..MJ..",
    "..MJ..",
    "KGGGGC",
    ".CMMC.",
    "..MJ..",
    "..JP..",
])
DECOR_BAT = (72, 19, [
    "................CMMP",
    "...............OGOC.",
    ".PJJJJJ.......OGGP..",
    ".CJGGGOKC....KGGGC..",
    "...CMOGGJ...KGGJJC..",
    "....JOGGGKKMKGGK....",
    "....J.JGGGGGGGOK....",
    "......JJCOGGOP......",
    "..........GGJ.......",
    "..........MJ........",
    "..........CP........",
])
DECOR_SPARK_L = (11, 29, [
    ".CK..",
    ".PO..",
    ".PO..",
    "MOGOK",
    "PMOPC",
    ".PO..",
    ".PM..",
])
DECOR_SPARK_R = (81, 49, [
    ".KO..",
    ".KO..",
    "MGGGK",
    ".KO..",
    ".KO..",
])
DECOR_ALL = (DECOR_SPARK_TOP, DECOR_BAT, DECOR_SPARK_L, DECOR_SPARK_R)
DECOR_DIM_ROW = {"SPARK_TOP": 3, "BAT": 3, "SPARK_L": 3, "SPARK_R": 2}
BAT_CGX = 82.5

BASE_RLE = [
    "",
    "",
    "",
    "",
    "",
    ".37E5CE4C",
    ".37H4D4H2B",
    ".33FB6E.5FE.CD3.2F",
    ".33BA3B2FE.E3.E2.CBE2.2BFEFE",
    ".31C2DAD2E.2CEDB3C.3C.FBF.FBDBC",
    ".31BHA2E.3EA3F2DFC.2CBDHDB.2BH2E",
    ".29EFDAHC.2EALA3B3F2ECFDH4B2.BA2FC.12P2",
    ".29FDH2B.CDAL2AD2F2EC2EB2DH6B.BHDE.12MJ",
    ".29FD2B.2CAL2A2B2C.C2.2CB2CEH4DC.DBE.12MJ",
    ".24KG3K.3CFBEAL2HDB.2ED2B.2EC.2BH3A2F.FB2.9KG4C",
    ".24KMK2O2M.EB2CDL2ADC.BDH2DBE.4CDH2A2B.EBD.10CM2C",
    ".25CPMG3.2CMPEDLAE.BH2AHD2B.CEFE2DHALACE2B2E.9MJ",
    ".23CJCMGO2GOP.CGKFA2.FA2HA2C.B4DBCEHAL2EBCB2E.9JP",
    ".23MJPG2K.G2OPCGKED.CL3A2B.2CB3A2DF2L3FC2BDE",
    ".20JMK2.OGKMKGOGOKGP.CEAL4A.EFE2DHA2BFCL4CECFE.21CM2P",
    ".20PMO.KGKCMO.MGJPG2P.EAL3ADEDBF.2DA2DBCAL3BE.E2.20OGOC",
    ".21COCKO.OMG.OGCPOPC.EHALAHEBAB.E.DA4E.LA3.2C2.6PJ5.7OG2P",
    ".22OPKGMCJPCGMPGM.2CDH2A2EFA2B.F2CA4B.HA3.10CJG3OKC.4KG3C",
    ".19E2C2PMO2PC2O2CJGM.2CH4AEFA2B.E2CA5EDA3DB.10CMOG2J.3KG2J2C",
    ".19DHB.KJO3K2J.M2PK.EBHDFAB.DA2C4.EA4ECDA3B.11JOG3K2MKG2K",
    ".19ED2C.CO2.JO2G2J.2B3HB2AF.A3.N3E.AHDABCBA2FAC.F2.7J.JG7OK",
    ".20BDE.5O3P2C.CBD3EBAF.A2HLI2N2.A2DHBCBA2CDHBFE.9J2COG2OP",
    ".24JK.3J2.4DA3DEDAF.A2.NI3N.DA.FBFBA2H.DAEC.13G2J",
    ".23JOK.JC.5BA4B2DHE.A2.I4NFEACEB2EBA2.DAHDE.12MJ",
    ".12CK.7CPJP.JOM.EB.2A4BCDAD.2HA.I5NCADFEBEBA2C.BHAB.12CP",
    ".12PO.7PGJ.KOGO.E.FBA3BCEA2DBCFA.I4N2CDAD.EF.DA2C.EA2F",
    ".12PO.6PG2O.CJG2.2FA4D.CDABHNHFA.I2NL.4DABCE.DA2C.CHADC",
    ".11MOGOK.3COG2M.2KGO.CA4DC2BAD.AIAFH.I3N4.DA2FC.D2AC.2FA2F",
    ".11PMOPC.5JG.4CPFA3DF.CHA2BLNIACDEI6N.BA3F.BDABC.CEHF",
    ".12PO.8J.6BDB3.EH2DFAI3NLBFI7N.DA2HF.DHAE.3DF",
    ".12PM.8C.F2CEC.EF2.EDB2EFLN5B2NI2N2LQ2DC2FA2CHDAECF.BE",
    ".24BFBDE.5CE.6FQN2FDCI2NLE.6F6.CE.FC",
    ".23FC.B2N4D.EC.BD.C.3LNLBFI2A.3C.BF.3DBN4.B",
    ".22BDC.B2DN3.2B2.L2CPK2DLI2NHDNLBPCPCLA.BAH.N3A.D",
    ".22BE.2BAFLN2.EB2.N2MGO2LI4N3ILGMGJNL.BA2.N2L.2BE",
    ".20CDB.2CBHB.BN.BDB.LN2G3NI8NG3N2L.BA2.NB.3B2",
    ".18FA2B.3BH2BC2.2AHBF.LI2NI11N4A.EHA2.2EC.2B2F",
    ".18FAHF.3DA2BCE.2AHB2.2LI16F.2BAHC.CBE.3FBC",
    ".16DHADBE.2FHA2BCBC.A2HB.ANI5N5I6N.EHAF.2CBE.3FDB",
    ".15CLAEC.2C.HA2BEF2C.A3H.CLN2I3N4LI4N2LEDAB.2CB2F.4CBDBFC",
    ".14A3C.4BCDA2.FBE.2FA3.4LI12L.2BAD.3CB2DE.4CEBABE",
    ".14AL.6BA3F2B2E.E3A2B.4EFHI6LF2.3BAD.3CB2DHF.5EA3F",
    ".14HC.6DA2BEB3E.2F2.CAB.5CA2L2A2E.5BAHBC.2CB2DB.2B.4FHE",
    ".14DC.4EDA2DEBD2C.3FBF.ADCJ2PC.2CQLC.2CJ3.2CA2F.3EBHA2EB.4FDE",
    ".15BE.2BA3DCEBD2.4CFD2ADCMJ2K.3L2.3KJMG2K.D2AD.2CBDA2B.4CBDE.3KO",
    ".15EBFBA3DCEDHAD.5EA3FKG2K.CFDLGHE2.KG4O.EA2E.2FBDA3.2CB3C.3KO",
    ".16DA3HBC2BDA2D.2BEA3DBKMOGCF2DNG2LBF2.G2JC2.2BAB.2EB2DA2E.CB2E.3MG3K",
    ".15BA2HDBC2BA2DBE.BDB2D2.4KMPHABLOMQDA2POP.5EABE.2CBDA3C2F.6KO",
    ".14EA3B2F.FBA2BC.DA2.5C2FE.PAL2BL2BL3PC2FC2.2EHB2C.2FDA4E.7KO",
    ".8F5BHABFBEC2DA3E.2AC.5EF3EC3NI2L2I2NC.CF2CFCED2BE.3FD2A3D",
    ".8DA4E.2EBF.2BA4E.2A.8CBDHDCFDNIN2DF.EDADEC.BABC.2FCFBDA5E",
    ".8DA2D2C.2B2C.CDA4D.2DB.3FE.2FDADFP.HBL2DABKPEBD2FCHB.C2.BE.CDHBA3BC",
    ".8BA2.4FBF.CA6B.2EDF2EFC.CDHB.CJ.BDEFBDEPMK.EB2C.3F2B2E.CDHDBA3HDE",
    ".9A2.4B2E.CA5DB.3D3BF.2BHDECKO.CEBLEC.POP.C3FE.2EBD2E.2FH2.FA4DE",
    ".9BA.3B2DE.CA4E2BE.2ECDFE.EHDFBEPO.CFL2E2.KOMEBC.F2C.CD3C.BEB2.2FHA3HE",
    ".10BE.2BDHBC.DA3.CBE.4B.2FHDB3CM.2EFCFEFC.MGPB2.6EDB.2BF.6H2A3C",
    ".14BDABC.2DHDF.EBC.5EA2D2AEPM.2D.LNLC.2CGPFAHF.4EDB.2BDE.5HFEA3C",
    ".10F2.2BDAHB.3BDBF.FC.5DA2DADJGC.FLBA.L2FC.JM.BADF2.2CFB2.CDHC.4HF.2DAC",
    ".9FE.2B3HA2B.2BDBF.FC.2CFDA2DADEJ2.3HCAL3E.3P2FA2B2F.3FB.CDHD.4HF.2CAC",
    ".9DE.2ABCDA3DC2FBF.E.3FBA3HAFCM.2CBC.C3.2EC.CKCDAD3E.2FE.BDAD.3EHF.3AC",
    ".9BE2BAB.EA3HDF.F2.3CB2DH2A2F.P2.EBDC2F2E.CBEC.K2FA2DAHBC.2FBDAF.3BAE.2CAE",
    ".10BDA2B.3BAHDBCF2.3ED2ABDAH.2C.F2BH.CF2BF.B2F.POCDADA2DB.2B2DF.2CBHB.2EBAC",
    ".10EDHADE.3ED3CF2.2BH2DBDAD.2MKEDA2EFD4AEFAHB.J2CADBA3DE.CBC.DA2F.3BHD",
    ".11EDA2D.3EBD2E.3BDADB2A2H.COC.EA2.BA2D2AD.HDC.PG.EA2BA3DC2BC.DA2E.2BD2B",
    ".12FDAF.E.2EDBC.2DA3DE.HAD.CJ.C.C3A3D2A2.3C2.JO.DABFH2DBE.3BDAE.2DE",
    ".13BA.CDF2B2C.2EHA3F.C.A.2OK.BF.2DA3FBA2D.CBF.2GMCBD.2EDBFC.3EABE",
    ".12EDE.FA2HFE.2EDA3.2EFCECMG.2BF.2B4.CBDB.CBF.2G2.2B.C2.B3E.2FHADEC",
    ".11CBH.CA3E.3EDHE.3ED2F.KG2.3FL2.8HL2.4G2C.3BF.3FD.2FBHA2DE2",
    ".11EB.3EAE.4DB.5ED2F.KOK.2DLI2L2A.2EL2NINL.3KM2.2B2F.5H.3EBA2FDC",
    ".11EDE2.CAH.3BDC2JP.2EDB.JO2CK.LNI3NL.CDNI4N.K2.JG.2B2F.2J2.DC.3EDB.BC",
    ".12ED2.EA2D.2BECJ3.2FDB.MGOCK.EDNLADF.K.BHLILB.K2.JGMK.B2.2J3C2.3EDB.BC",
    ".16D2AD.BF.CJ2MJ.BD.JG2OCK.4D.3CK.3E2.3K3PGOK.B2CPJ2M.2E.2EDEFC",
    ".14EB3E2.BCKJMJ2.EBE.MGM.CPK.2MFO.2K2.2KJ2K.CK3.OGOC2BC.J2MJ.F.CFE2B",
    ".19C.E.JO2MJ.CFCM2GM.PJ2.2CJK.2K2.3P2.2KJ2P.OGO2CEC.JMG2.3F2C",
    ".17FBDC.2MG3K.C.2OG2M.J3.2EQC.2K2.3PB.2KJ3.G4J.C2PG3",
    ".17DB2C.JG3M.CEKJG3M.J3.2FAF.2CK.2CD2C.KJ3.JOG3KEC2MG3",
    ".17HB.2KMO3C.CEJMG3M.PJ2.2FAB.2K2.2ED2C.CJ3.2MG3MEC.2OG2K",
    ".17FDC.JM.5CJMG4OJ.C2.2FA2.6EADC.7MG3OMK.2K2M2",
    ".18E.2KJ.5KMCMG2OM2.6HA.6EAF.8JMO3MP.4OK",
    ".22PJ.3PJK.CO2M3J.5F2.6CFC.7CJM2P.KMP.2JK",
    ".23J.10JM2J.3CB4C.3EB4.5KM2J.8K",
    ".36KJ.3CDA3C.3BHADB.5KMJP",
    ".37C.3CBA3E.3BA2DF.5KP",
    "",
    ".42C4.5C4",
    "",
    "",
    "",
    "",
    "",
    "",
]


def pal_color(ch: str):
    return (BASE_PAL + list(EXTRA.values()))[SYMS.index(ch)]


def _pal(v):
    for c in BASE_PAL:
        if c[:3] == v:
            return c
    raise SystemExit("tone %r missing from BASE_PAL" % (v,))


OUTLINE = _pal((8, 5, 8))
SKIN = _pal((233, 197, 204))
SKIN_SHA = _pal((166, 128, 142))
SLEEVE = _pal((27, 18, 29))
SLEEVE_HI = _pal((42, 28, 45))
CRIMSON_DEEP = _pal((38, 8, 20))
IRIS_TONES = {(99, 15, 41), (87, 13, 36), (73, 10, 31)}

EYE_L = (37, 38, 46, 47)
EYE_R = (51, 38, 60, 47)


def _in_box(x: int, y: int, box) -> bool:
    return box[0] <= x < box[2] and box[1] <= y < box[3]


def _is_hair_pixel(x: int, y: int) -> bool:
    """True for Velmira's crown, bangs, and long wavy side-locks; False for
    her eye lashes/brows, gothic collar, corset, sleeves, skirt, and boots."""
    if _in_box(x, y, EYE_L) or _in_box(x, y, EYE_R):
        return False
    # Mouth line
    if 45 <= x <= 51 and 44 <= y <= 46:
        return False
    # Above collar/neck: everything non-rose/non-skin/non-eye is hair
    if y <= 47:
        return True
    # Below y=47, her gothic dress forms a central cone from shoulders to hem;
    # the billowing wavy locks cascade outside that cone on both sides!
    if y <= 76:
        dress_half_w = 9.5 + (y - 48) * 0.44
        if abs(x - 48.0) > dress_half_w:
            return True
    return False


def apply_white_hair(img: Image.Image) -> None:
    """Convert Velmira's dark-plum hair into luminous moonlit silver-white
    while keeping crisp dark silhouette outlines and her black-crimson dress."""
    px = img.load()
    # Keep a 1px dark outer boundary crisp by checking alpha neighbors
    alpha_grid = [[px[x, y][3] > 0 for x in range(FRAME)] for y in range(FRAME)]
    for y in range(FRAME):
        for x in range(FRAME):
            r, g, b, a = px[x, y]
            if a == 0 or not _is_hair_pixel(x, y):
                continue
            mapped = WHITE_HAIR_MAP.get((r, g, b))
            if mapped is None:
                continue
            # Preserve 1px silhouette border if touching transparency
            touches_empty = False
            for ny in (y - 1, y, y + 1):
                for nx in (x - 1, x, x + 1):
                    if nx < 0 or nx >= FRAME or ny < 0 or ny >= FRAME or not alpha_grid[ny][nx]:
                        touches_empty = True
                        break
                if touches_empty:
                    break
            if touches_empty and (r, g, b) in ((23, 13, 22), (27, 18, 29)):
                px[x, y] = (72, 64, 96, 255)
            else:
                px[x, y] = mapped


def decode_base() -> Image.Image:
    pal = BASE_PAL + list(EXTRA.values())
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    px = img.load()
    for y, rle in enumerate(BASE_RLE):
        x = 0
        i = 0
        while i < len(rle):
            ch = rle[i]
            i += 1
            n = ""
            while i < len(rle) and rle[i].isdigit():
                n += rle[i]
                i += 1
            run = int(n) if n else 1
            if ch != ".":
                idx = SYMS.index(ch)
                for k in range(run):
                    px[x + k, y] = pal[idx]
            x += run
    erase_decor(img)
    apply_white_hair(img)
    return img


def blit(dst, src, ox=0, oy=0) -> None:
    dst.alpha_composite(src, (ox, oy))


def shift_strip(img, x0, y0, x1, y1, dx=0, dy=0, clear=True) -> None:
    strip = img.crop((x0, y0, x1, y1))
    if clear:
        blank = Image.new("RGBA", strip.size, (0, 0, 0, 0))
        img.paste(blank, (x0, y0))
    blit(img, strip, x0 + dx, y0 + dy)


def _each_decor_pt(snip, dim=False):
    x0, y0, rows = snip
    key = {id(DECOR_SPARK_TOP): "SPARK_TOP", id(DECOR_BAT): "BAT",
           id(DECOR_SPARK_L): "SPARK_L", id(DECOR_SPARK_R): "SPARK_R"}[id(snip)]
    bar = DECOR_DIM_ROW[key]
    for j, row in enumerate(rows):
        if dim and key != "BAT" and j != bar:
            continue
        for i, ch in enumerate(row):
            if ch != ".":
                yield x0 + i, y0 + j, ch


def erase_decor(img) -> None:
    for snip in DECOR_ALL:
        for x, y, _ch in _each_decor_pt(snip):
            img.putpixel((x, y), (0, 0, 0, 0))


def draw_decor(img, bat_dir, spark_state) -> None:
    for x, y, ch in _each_decor_pt(DECOR_BAT):
        d = abs(x - BAT_CGX)
        dy = bat_dir * (2 if d >= 7 else 1 if d >= 3.5 else 0)
        img.putpixel((x, y - dy), pal_color(ch))
    for name, snip in (("TOP", DECOR_SPARK_TOP), ("L", DECOR_SPARK_L),
                       ("R", DECOR_SPARK_R)):
        for x, y, ch in _each_decor_pt(snip, dim=spark_state.get(name, False)):
            img.putpixel((x, y), pal_color(ch))


def blood_bead(img, cx, cy, r) -> None:
    """Swirling liquid crimson Blood Orb summoned before her whip strike."""
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=OUTLINE)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=EXTRA["blood"])
    d.ellipse([cx - 2, cy - r + 1, cx + 1, cy], fill=EXTRA["blood_hi"])
    img.putpixel((cx - 1, cy - r + 1), EXTRA["white"])
    # Orbiting water-like crimson tendril wisps around the orb
    for ang in (0.3, 2.2, 4.1):
        wx = int(round(cx + math.cos(ang) * (r + 2)))
        wy = int(round(cy + math.sin(ang) * (r + 2)))
        if 0 <= wx < FRAME and 0 <= wy < FRAME:
            img.putpixel((wx, wy), EXTRA["blood_hi"])
        if 0 <= wx + 1 < FRAME and 0 <= wy < FRAME:
            img.putpixel((wx + 1, wy), EXTRA["blood"])


def whip_cast_arm(img) -> None:
    """Graceful flared gothic bell-sleeve & pale hand whipping a curved stream
    of liquid crimson blood out to the right."""
    # Patch corset where folded hands were
    patch = Image.new("RGBA", (10, 7), (0, 0, 0, 0))
    for y in range(7):
        for x in range(10):
            patch.putpixel((x, y), SLEEVE if (x + y) % 3 else SLEEVE_HI)
    blit(img, patch, 43, 54)

    # Curved gothic flared bell-sleeve tapering to wrist, with crimson trim
    for x in range(55, 74):
        t = (x - 55) / 18.0
        cy = 57.0 - 2.0 * math.sin(t * math.pi)
        half_h = 2.6 + 2.2 * (1.0 - abs(t - 0.55))
        y0 = int(round(cy - half_h))
        y1 = int(round(cy + half_h))
        for y in range(y0 - 1, y1 + 2):
            if 0 <= x < FRAME and 0 <= y < FRAME:
                if y == y0 - 1 or y == y1 + 1:
                    img.putpixel((x, y), OUTLINE)
                elif y == y0:
                    img.putpixel((x, y), SLEEVE_HI)
                elif y == y1 and x >= 66:
                    img.putpixel((x, y), (120, 16, 44, 255))
                else:
                    img.putpixel((x, y), SLEEVE)

    # Delicate pale hand & extended fingers at x=73..78
    for y in range(54, 59):
        for x in range(73, 78):
            if y in (54, 58) or x == 77:
                img.putpixel((x, y), OUTLINE if y in (54, 58) else SKIN_SHA)
            else:
                img.putpixel((x, y), SKIN)
    img.putpixel((78, 55), SKIN)
    img.putpixel((78, 56), SKIN_SHA)

    # Sinuous whip-stream of liquid blood arcing from hand to a glossy Blood Orb!
    for i in range(18):
        u = i / 17.0
        wx = int(round(78 + u * 14.0))
        wy = int(round(56 - 4.0 * math.sin(u * math.pi * 1.25)))
        for dy in (-1, 0, 1):
            if 0 <= wx < FRAME and 0 <= wy + dy < FRAME:
                col = EXTRA["blood_hi"] if dy == -1 else (EXTRA["blood"] if dy == 0 else CRIMSON_DEEP)
                img.putpixel((wx, wy + dy), col)
    blood_bead(img, 90, 56, 3)


def _blaze_eyes(img) -> None:
    for (x0, y0, x1, y1) in (EYE_L, EYE_R):
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b, a_ = img.getpixel((x, y))
                if a_ and (r, g, b) in IRIS_TONES:
                    img.putpixel((x, y), EXTRA["iris_hi"])


def _shut_eyes(img) -> None:
    for (x0, y0, x1, y1) in (EYE_L, EYE_R):
        lid_row = None
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b, a_ = img.getpixel((x, y))
                if a_ and (r, g, b) in IRIS_TONES:
                    img.putpixel((x, y), (0, 0, 0, 0))
                    if lid_row is None:
                        lid_row = y
        if lid_row is not None:
            for x in range(x0, x1):
                r, g, b, a_ = img.getpixel((x, lid_row))
                if a_:
                    img.putpixel((x, lid_row), SKIN_SHA)


def frame_idle() -> Image.Image:
    return decode_base()


def frame_walk(which: str) -> Image.Image:
    img = decode_base()
    img.paste(img.crop((0, 1, FRAME, FRAME)), (0, 0))
    img.paste(Image.new("RGBA", (FRAME, 1), (0, 0, 0, 0)), (0, FRAME - 1))
    if which == "A":
        shift_strip(img, 48, 76, 60, 94, 0, -3)
    else:
        shift_strip(img, 37, 76, 48, 94, 0, -3)
    return img


def frame_cast(windup: bool) -> Image.Image:
    img = decode_base()
    if windup:
        _blaze_eyes(img)
        blood_bead(img, 48, 60, 4)
    else:
        _blaze_eyes(img)
        whip_cast_arm(img)
    return img


def frame_blink() -> Image.Image:
    img = decode_base()
    _shut_eyes(img)
    return img


def frame_hurt() -> Image.Image:
    """Recoiling hurt pose: shifted back 3 px, wincing > < lashes, open mouth + tiny fang."""
    base = decode_base()
    _shut_eyes(base)
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    blit(img, base, -3, 1)
    # Draw sharp wince brows & open 'akh!' mouth with white vampire fang
    for dx in range(4):
        img.putpixel((38 + dx, 40 + dx // 2), OUTLINE)
        img.putpixel((55 - dx, 40 + dx // 2), OUTLINE)
    for x in range(44, 48):
        img.putpixel((x, 45), CRIMSON_DEEP)
        img.putpixel((x, 46), EXTRA["blood"])
    img.putpixel((44, 45), EXTRA["white"])
    img.putpixel((47, 45), EXTRA["white"])
    return img


def frame_bat_dissolve() -> Image.Image:
    """Crimson mist & mini bat silhouettes as Velmira vanishes into her Bat Swarm!"""
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Swirling crimson mist core
    for cx, cy, rx, ry, col in [
        (48, 52, 16, 24, (75, 10, 30, 175)),
        (48, 50, 11, 18, (145, 18, 48, 210)),
        (48, 48, 6, 11, (220, 42, 76, 235)),
    ]:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col)
    # Three crisp pixel bats erupting out of the mist
    for bx, by in ((34, 32), (58, 28), (48, 64)):
        for dx in range(-6, 7):
            wy = abs(dx) // 2
            img.putpixel((bx + dx, by - wy), OUTLINE)
            img.putpixel((bx + dx, by - wy + 1), EXTRA["blood"])
        img.putpixel((bx - 1, by), EXTRA["blood_hi"])
        img.putpixel((bx + 1, by), EXTRA["blood_hi"])
    return img


def build_sheet() -> Image.Image:
    frames = [
        frame_idle(),
        frame_walk("A"),
        frame_walk("B"),
        frame_cast(True),
        frame_cast(False),
        frame_blink(),
        frame_hurt(),
        frame_bat_dissolve(),
    ]
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * FRAME, 0))
    return sheet


AMBIENT_FRAMES = [
    (0, {"TOP": False, "L": False, "R": False}),
    (1, {"TOP": True, "L": False, "R": True}),
    (-1, {"TOP": False, "L": True, "R": True}),
]


def build_ambient_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * len(AMBIENT_FRAMES), FRAME), (0, 0, 0, 0))
    for i, (bat_dir, spark_state) in enumerate(AMBIENT_FRAMES):
        fr = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        draw_decor(fr, bat_dir, spark_state)
        sheet.alpha_composite(fr, (i * FRAME, 0))
    return sheet


def build_preview(sheet: Image.Image, ambient: Image.Image) -> Image.Image:
    zoom, pad = 3, 14
    labels = ["0 idle", "1 walk A", "2 walk B", "3 gather", "4 blood whip", "5 blink", "6 hurt", "7 bat mist"]
    w = pad + FRAMES * (FRAME * zoom + pad)
    h = 34 + FRAME * zoom + 28
    img = Image.new("RGBA", (w, h), (22, 18, 28, 255))
    d = ImageDraw.Draw(img)
    d.text((pad, 10), "VELMIRA (WHITE HAIR) - 8 frames x 96x96", fill=(242, 234, 248, 255))
    for i in range(FRAMES):
        x = pad + i * (FRAME * zoom + pad)
        frame = sheet.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        img.alpha_composite(frame.resize((FRAME * zoom, FRAME * zoom), Image.NEAREST), (x, 32))
        d.text((x, 32 + FRAME * zoom + 4), labels[i], fill=(210, 195, 224, 255))
    return img


def main() -> None:
    sheet = build_sheet()
    sheet.save("assets/textures/player_shabnam.png")
    print("wrote assets/textures/player_shabnam.png", sheet.size)
    ambient = build_ambient_sheet()
    ambient.save("assets/textures/velmira_ambient.png")
    build_preview(sheet, ambient).save("docs/images/velmira_preview.png")


if __name__ == "__main__":
    main()
