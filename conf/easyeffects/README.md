# EasyEffects

`install.sh` is discovered by the user configuration stage of `make setup`. It installs and initially activates the `OS-Subwoofer` output preset through EasyEffects' native CLI and enables native desktop autostart. Subsequent setup runs preserve an explicitly selected different preset. The original EasyEffects databases are saved privately under the user's OS state directory before first application; existing presets remain available.

The preset targets perceived bass on laptop speakers rather than physical subwoofer extension. It uses a 60 Hz high-pass with 6 dB input headroom, moderate harmonics below 110 Hz, and a final true peak limiter at -2 dB with threshold boost and automatic leveling disabled. It preserves the hardware output, volume, mute state and microphone effects. A limiter reduces digital clipping risk; it cannot guarantee freedom from speaker distortion at high listening volumes.

Choose another output preset or enable EasyEffects' bypass to return to unprocessed audio. This preset has an empty excluded application list. Review exclusions in EasyEffects if you previously maintained one.

The JSON keys and enum values follow [EasyEffects 8.2.9](https://github.com/wwmm/easyeffects/tree/v8.2.9/src/contents/kcfg); limiter behavior follows the [upstream manual](https://github.com/wwmm/easyeffects/blob/v8.2.9/src/contents/docs/plugins/limiter.md).
