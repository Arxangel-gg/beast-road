# Hero reference frames

One frame per row of `game/art/hero/hero_idle.png`, extracted so that art tools
can be handed a **URL** instead of twenty thousand characters of base64.

These are not game assets and are deliberately outside `game/art/`, so the asset
manifest does not describe them and `asset_report` does not scan them. They are
inputs to the art pipeline, the same way the style images used for gear and
foliage are.

**Why they exist.** The Warden's sheets came from a PixelLab character that no
longer exists in the account - the only character there now is a different
figure, a plain hooded warrior with no skull, no lantern and no banner - so a
new eight-direction state cannot be generated from the source. Anything that
wants to add a hero animation has to work from the shipped pixels, and these are
the shipped pixels, one frame per rotation.

Row order is the animator's own: `HeroAnimator` treats direction 2 as south.
