import 'package:flutter/material.dart';
import '../models/equalizer_preset.dart';
import '../models/eq_band_info.dart';
import '../services/app_audio_service.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final AppAudioService _audioService = AppAudioService();

  bool _isLoading = true;
  bool _enabled = false;
  List<EqBandInfo> _bands = [];
  late List<double> _liveGains; // UI-তে দেখানোর জন্য local state
  String _activePresetName = 'Flat';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _bands = await _audioService.getBandInfos();
      _liveGains = _bands.map((b) => b.currentGain).toList();
    } catch (e) {
      _bands = [];
      _liveGains = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEqualizer(bool value) async {
    setState(() => _enabled = value);
    await _audioService.setEqualizerEnabled(value);
  }

  Future<void> _applyPreset(EqualizerPreset preset) async {
    setState(() => _activePresetName = preset.name);
    if (!_enabled) {
      await _toggleEqualizer(true);
    }
    await _audioService.applyPreset(preset);
    setState(() {
      for (int i = 0; i < _liveGains.length && i < preset.gains.length; i++) {
        _liveGains[i] = preset.gains[i];
      }
    });
  }

  Future<void> _onBandChanged(int index, double value) async {
    await _audioService.setBandGain(index, value);
    setState(() {
      _liveGains[index] = value;
      _activePresetName = 'Custom';
    });
  }

  String _formatFrequency(double hz) {
    if (hz >= 1000) {
      final khz = hz / 1000;
      return '${khz % 1 == 0 ? khz.toInt() : khz.toStringAsFixed(1)}kHz';
    }
    return '${hz.round()}Hz';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Text('On', style: TextStyle(fontSize: 13)),
                Switch(
                  value: _enabled,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: _toggleEqualizer,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (!_audioService.isEqualizerSupported || _bands.isEmpty)
              ? _buildUnsupportedNotice()
              : _buildEqualizerBody(),
    );
  }

  Widget _buildUnsupportedNotice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.equalizer, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Equalizer এই ডিভাইসে এখনো সাপোর্টেড নয়',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizerBody() {
    return Opacity(
      opacity: _enabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !_enabled,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Presets',
              style: TextStyle(
                  color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EqualizerPresets.all.map((preset) {
                final isSelected = _activePresetName == preset.name;
                return ChoiceChip(
                  label: Text(preset.name),
                  selected: isSelected,
                  selectedColor: Colors.deepPurpleAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.grey[900],
                  onSelected: (_) => _applyPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const Text(
              'Manual',
              style: TextStyle(
                  color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_bands.length, (index) {
                  final band = _bands[index];
                  return _BandSlider(
                    minDb: band.minDb,
                    maxDb: band.maxDb,
                    label: _formatFrequency(band.frequencyHz),
                    value: _liveGains[index],
                    onChanged: (value) => _onBandChanged(index, value),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final double minDb;
  final double maxDb;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.minDb,
    required this.maxDb,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(minDb, maxDb);
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
                activeTrackColor: Colors.deepPurpleAccent,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.deepPurpleAccent,
              ),
              child: Slider(
                min: minDb,
                max: maxDb,
                value: clamped,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}
