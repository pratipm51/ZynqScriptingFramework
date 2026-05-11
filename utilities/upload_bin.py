#!/usr/bin/env python3
import sys
import argparse
import os
import time
import subprocess

try:
    import serial
except ImportError:
    print("❌ Error: 'pyserial' is not installed.")
    print("Please install it using: pip install pyserial")
    sys.exit(1)

def get_port_owner(device):
    """Find the process using the serial port."""
    try:
        # Use fuser to find the process ID
        result = subprocess.check_output(["fuser", device], stderr=subprocess.STDOUT)
        pids = result.decode().strip().split()
        return [int(p) for p in pids if p.isdigit()]
    except:
        return []

def main():
    parser = argparse.ArgumentParser(description="Upload a binary file to NeoRV32 via UART.")
    parser.add_argument("device", help="USB TTY device (e.g. /dev/ttyUSB0)")
    parser.add_argument("baud", type=int, help="Baud rate (e.g. 19200)")
    parser.add_argument("file", help="Path to the .bin file")
    parser.add_argument("-f", "--force", action="store_true", help="Automatically close conflicting process (e.g. screen)")
    
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"❌ Error: File not found: {args.file}")
        sys.exit(1)

    # Check if port is busy
    pids = get_port_owner(args.device)
    if pids:
        if args.force:
            print(f"🛠️  Port {args.device} is busy (PIDs: {pids}). Closing conflicting processes...")
            for pid in pids:
                os.system(f"kill -9 {pid} 2>/dev/null")
            time.sleep(1)
        else:
            print(f"⚠️  Warning: Port {args.device} is already in use by PID(s): {pids}")
            print(f"   (This is likely your terminal emulator like 'screen' or 'minicom')")
            print(f"   Close the terminal or use --force to kill it automatically.")
            sys.exit(1)

    file_size = os.path.getsize(args.file)
    print(f"🚀 Starting upload to {args.device} ({args.baud} baud)")
    print(f"📦 File: {args.file} ({file_size} bytes)")

    try:
        # Open serial port
        ser = serial.Serial(
            port=args.device,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
        
        with open(args.file, "rb") as f:
            data = f.read()
            
            start_time = time.time()
            ser.write(data)
            ser.flush()
            end_time = time.time()

        elapsed = end_time - start_time
        print(f"✅ Upload Complete!")
        print(f"🕒 Time taken: {elapsed:.2f} seconds")
        print(f"📊 Avg speed: {(file_size/elapsed)/1024:.2f} KB/s")

        ser.close()

    except serial.SerialException as e:
        print(f"❌ Serial Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
