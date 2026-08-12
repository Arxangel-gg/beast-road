Drop generated audio here, named after the id from docs/SFX_PROMPTS.md.

  sfx_war_horn.mp3        ->  game/audio/sfx/sfx_war_horn.ogg
  music_boss.wav          ->  game/audio/music/music_boss.ogg

Extension does not matter going in - mp3, wav, ogg and flac all work.
Everything is converted to OGG on the way in, because Godot cannot loop an
MP3 seamlessly: the format pads the start and end of every file, so a looping
MP3 always ticks.

Say the word once files are in here and they will be trimmed, normalised,
converted and filed.
