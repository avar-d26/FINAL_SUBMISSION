import math

# Constants
FS = 48000                   # Sample rate (Hz)
FFT_SIZE = 1024              # FFT points (changed from 8192 to 1024)
BIN_WIDTH = FS / FFT_SIZE    # Now 46.875 Hz/bin (was 5.859375 Hz/bin)

def piano_freq(n):
    """Calculate frequency for piano key n (1-88) using equal temperament tuning"""
    return 440.0 * (2 ** ((n - 49) / 12))

def get_note_name(key):
    """Get piano note name for key number (1-88)"""
    note_names = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
    note_index = (key - 1) % 12
    octave = (key + 8) // 12
    return note_names[note_index] + str(octave)

def generate_key_map():
    """Generate bin assignments where each key gets exactly one closest bin"""
    key_freqs = [piano_freq(n) for n in range(1, 89)]
    min_bin = max(0, math.floor(20.0 / BIN_WIDTH))
    max_bin = min(FFT_SIZE//2 - 1, math.ceil(4500.0 / BIN_WIDTH))
    
    # Create mapping of bins to keys (one key per bin)
    bin_to_key = {}
    for bin_num in range(min_bin, max_bin + 1):
        freq = bin_num * BIN_WIDTH
        # Find the closest piano key to this bin's frequency
        closest_key = min(
            range(1, 89),
            key=lambda k: abs(math.log(freq) - math.log(piano_freq(k))) if freq > 0 else float('inf')
        )
        bin_to_key[bin_num] = closest_key
    
    # Now ensure each key gets only one bin (the closest one)
    key_to_bin = {}
    for bin_num, key in bin_to_key.items():
        # If this key hasn't been assigned yet, or this bin is closer than previous assignment
        if key not in key_to_bin or \
           abs(bin_num * BIN_WIDTH - piano_freq(key)) < \
           abs(key_to_bin[key] * BIN_WIDTH - piano_freq(key)):
            key_to_bin[key] = bin_num
    
    # Create final mapping with frequency info
    key_map = []
    for key in range(1, 89):
        if key in key_to_bin:
            bin_num = key_to_bin[key]
            ideal_freq = piano_freq(key)
            actual_freq = bin_num * BIN_WIDTH
            cents_error = 1200 * math.log2(actual_freq/ideal_freq) if actual_freq > 0 else 0
            key_map.append((key, bin_num, ideal_freq, actual_freq, cents_error))
        else:
            # With 1024-point FFT, some higher keys might not get assigned
            print(f"Warning: Key {key} not assigned a bin")
    
    return key_map

def generate_vhdl_case_statement(key_map):
    """Generate simplified VHDL case statement with direct assignment"""
    # Create mapping from bin to key info
    bin_assignments = {}
    for key, bin_num, ideal_freq, actual_freq, cents_error in key_map:
        note = get_note_name(key)
        bin_assignments[bin_num] = (key, note, ideal_freq, actual_freq, cents_error)
    
    vhdl_code = "mapp : process(clkb_i)\n"
    vhdl_code += "begin\n"
    vhdl_code += "    if rising_edge(clkb_i) then\n"
    vhdl_code += "        if (rst = '1') then\n"
    vhdl_code += "            paino <= (others => '0');\n"
    vhdl_code += "        elsif (buildbinreg_en = '1') then\n"
    vhdl_code += "            -- Default: keep previous state\n"
    vhdl_code += "            paino <= paino;\n"
    vhdl_code += "            \n"
    vhdl_code += "            case addr is\n"
    
    # Generate case statements in bin number order
    for bin_num in sorted(bin_assignments.keys()):
        key, note, ideal_freq, actual_freq, cents_error = bin_assignments[bin_num]
        vhdl_code += f"              -- Key {key:2} ({note}) - Bin {bin_num:4} ({actual_freq:7.2f} Hz) vs {ideal_freq:7.2f} Hz ({cents_error:+6.1f} cents)\n"
        vhdl_code += f"              when {bin_num:4} => paino({key-1}) <= data_i;\n"
    
    vhdl_code += "              when others => paino <= paino;\n"
    vhdl_code += "            end case;\n"
    vhdl_code += "        end if;\n"
    vhdl_code += "    end if;\n"
    vhdl_code += "end process;"
    
    return vhdl_code

if __name__ == "__main__":
    print("Generating piano key mapping (1 bin per key) for 1024-point FFT...")
    key_map = generate_key_map()
    
    print("\nGenerating VHDL case statement:")
    vhdl_code = generate_vhdl_case_statement(key_map)
    print(vhdl_code)