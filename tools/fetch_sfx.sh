#!/bin/sh
# Downloads the sourced voice/creature sounds and converts them to 22.05 kHz mono PCM
# WAVs in assets/audio (the web build needs PCM). Licenses and authors: CREDITS.md.
#   VoiceBosch "DEATH SOUNDS (Male)"  CC-BY-SA 4.0  -> voice_die_NN
#   Exewin "Death Sounds"              CC0           -> voice_pain_NN
#   rubberduck "80 CC0 creature SFX"   CC0           -> dog_*, llama_*, jaguar_roar_*, bug_die_*, stone_groan_*
set -e
cd "$(dirname "$0")/.."
OUT=assets/audio
TMP=$(mktemp -d)
OGA=https://opengameart.org/sites/default/files

conv() { # src dst [extra ffmpeg filters]
	ffmpeg -loglevel error -y -i "$1" -ac 1 -ar 22050 -c:a pcm_s16le ${3:+-af "$3"} "$OUT/$2.wav"
}

for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
	curl -sf -o "$TMP/die_$i.wav" "$OGA/$i._death_groan_male.wav"
	conv "$TMP/die_$i.wav" "voice_die_$i" "silenceremove=start_periods=1:start_threshold=-45dB,afade=t=out:st=2.2:d=0.3,atrim=0:2.5"
done

curl -sf -o "$TMP/exewin.zip" "$OGA/exewinDeathSoundsPack.zip"
unzip -o -q "$TMP/exewin.zip" -d "$TMP/exewin"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
	conv "$TMP/exewin/exewinDeathSoundsPack/$i.ogg" "voice_pain_$(printf %02d $i)"
done

curl -sf -o "$TMP/creature.zip" "$OGA/80-CC0-creature-SFX_0.zip"
unzip -o -q "$TMP/creature.zip" -d "$TMP/creature"
C="$TMP/creature"
conv "$C/barking_01.ogg" dog_bark_01
conv "$C/barking_02.ogg" dog_bark_02
for i in 1 2 3 4 5; do
	conv "$C/hurt_0$i.ogg" "dog_yelp_0$i" "asetrate=22050*1.35,aresample=22050"
done
conv "$C/scream_01.ogg" llama_scream_01
conv "$C/scream_02.ogg" llama_scream_02
for i in 1 2 3; do
	conv "$C/spit_0$i.ogg" "llama_spit_0$i"
	conv "$C/roar_0$i.ogg" "jaguar_roar_0$i"
done
for i in 1 2 3 4; do
	conv "$C/bug_0$i.ogg" "bug_die_0$i"
done
for i in 1 2 3; do
	conv "$C/monster_0$i.ogg" "stone_groan_0$i" "asetrate=22050*0.7,aresample=22050"
done
rm -rf "$TMP"
echo "sourced sounds written to $OUT"
