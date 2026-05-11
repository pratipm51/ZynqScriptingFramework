#!/usr/bin/env python3
import sys
import argparse
import os
import time
import threading
import tty
import termios

try:
    import serial
except ImportError:
    print("❌ Error: 'pyserial' is not installed.")
    print("Please install it using: pip install pyserial")
    sys.exit(1)

def terminal_handler(ser):
    """Handles incoming data from UART and prints to stdout."""
    while True:
        try:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting).decode('utf-8', errors='replace')
                print(data, end='', flush=True)
            time.sleep(0.01)
        except:
            break

def upload_logic(ser, file_path):
    """Binary upload logic with progress indicator."""
    if not os.path.exists(file_path):
        print(f"\r\n❌ Error: File not found: {file_path}")
        return False

    file_size = os.path.getsize(file_path)
    print(f"\r\n🚀 Starting binary upload: {file_path} ({file_size} bytes)...")
    
    try:
        with open(file_path, "rb") as f:
            data = f.read()
            start_time = time.time()
            
            chunk_size = 1024
            sent = 0
            for i in range(0, len(data), chunk_size):
                chunk = data[i:i+chunk_size]
                ser.write(chunk)
                sent += len(chunk)
                # Print progress
                percent = (sent / file_size) * 100
                print(f"\r📤 Progress: {percent:3.0f}% [{sent}/{file_size} bytes]", end="", flush=True)
            
            ser.flush()
            end_time = time.time()

        elapsed = end_time - start_time
        print(f"\n✅ Upload Complete! ({elapsed:.2f}s, {(file_size/elapsed)/1024:.2f} KB/s)")
        print("⌨️  Returning to Terminal Mode...")
        return True
    except Exception as e:
        print(f"\n❌ Upload failed: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="NeoRV32 Interactive Terminal & Uploader")
    parser.add_argument("device", help="USB TTY device (e.g. /dev/ttyUSB0)")
    parser.add_argument("baud", type=int, help="Baud rate (e.g. 19200)")
    parser.add_argument("file", help="Path to the .bin file")
    parser.add_argument("-t", "--terminal", action="store_true", help="Start in terminal mode")
    
    args = parser.parse_args()

    # Save original terminal settings for restoration
    old_settings = termios.tcgetattr(sys.stdin)

    try:
        ser = serial.Serial(port=args.device, baudrate=args.baud, timeout=0.1)
        print(f"📡 Connected to {args.device} at {args.baud} baud.")
        
        if args.terminal:
            print("⌨️  Terminal Mode Active. (Ctrl+C to exit, Ctrl+U to trigger upload)")
            
            # Start receiver thread
            t = threading.Thread(target=terminal_handler, args=(ser,), daemon=True)
            t.start()

            # Enable raw mode for stdin (immediate character transmission)
            tty.setraw(sys.stdin.fileno())

            while True:
                char = sys.stdin.read(1)
                if char == '\x03': # Ctrl+C
                    break
                elif char == '\x15': # Ctrl+U
                    # Restore settings temporarily to print upload info clearly
                    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
                    upload_logic(ser, args.file)
                    # Go back to raw mode
                    tty.setraw(sys.stdin.fileno())
                else:
                    ser.write(char.encode('utf-8'))
        else:
            upload_logic(ser, args.file)
            ser.close()

    except Exception as e:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
        print(f"\n❌ Error: {e}")
        sys.exit(1)
    finally:
        # Always restore terminal settings
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)

if __name__ == "__main__":
    main()
