# Wireless Microphone Windows Client
# Receives UDP audio packets and outputs to virtual microphone

import socket
import threading
import queue
import sys
import time
from datetime import datetime

try:
    import pyaudio
except ImportError:
    print("ERROR: pyaudio not installed. Run: pip install pyaudio")
    sys.exit(1)


class AudioConfig:
    """Audio configuration constants"""
    SAMPLE_RATE = 48000      # Hz
    BIT_DEPTH = 16           # bits
    CHANNELS = 1             # mono
    PORT = 55555             # UDP port
    CHUNK_SIZE = 4800        # bytes (~100ms of audio)
    MAX_QUEUE_SIZE = 50      # max packets in queue to prevent latency buildup


class UDPAudioReceiver:
    """
    Receives raw PCM audio packets via UDP and outputs to audio device.
    Uses a thread-safe queue to buffer packets and prevent jitter.
    """
    
    def __init__(self, host='0.0.0.0', port=AudioConfig.PORT):
        self.host = host
        self.port = port
        self.socket = None
        self.audio_queue = queue.Queue(maxsize=AudioConfig.MAX_QUEUE_SIZE)
        self.running = False
        self.stats = {
            'packets_received': 0,
            'packets_dropped': 0,
            'bytes_received': 0,
            'start_time': None
        }
        
    def start_udp_listener(self):
        """Start UDP listener in background thread"""
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.socket.bind((self.host, self.port))
        self.socket.settimeout(1.0)  # Allow periodic check for shutdown
        
        self.running = True
        self.stats['start_time'] = datetime.now()
        
        print(f"[UDP] Listening on {self.host}:{self.port}")
        
        # Start receiver thread
        receiver_thread = threading.Thread(target=self._receive_loop, daemon=True)
        receiver_thread.start()
        
    def _receive_loop(self):
        """Main UDP receive loop"""
        while self.running:
            try:
                data, addr = self.socket.recvfrom(AudioConfig.CHUNK_SIZE)
                
                if len(data) > 0:
                    self.stats['packets_received'] += 1
                    self.stats['bytes_received'] += len(data)
                    
                    # Add to queue, drop if full to prevent latency buildup
                    try:
                        self.audio_queue.put_nowait(data)
                    except queue.Full:
                        self.stats['packets_dropped'] += 1
                        # Drop oldest packet to make room for new one
                        try:
                            self.audio_queue.get_nowait()
                            self.audio_queue.put_nowait(data)
                        except queue.Empty:
                            pass
                            
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"[ERROR] UDP receive error: {e}")
                    
    def stop(self):
        """Stop the UDP receiver"""
        self.running = False
        if self.socket:
            self.socket.close()
            self.socket = None
            
    def get_queue_size(self):
        """Get current queue depth"""
        return self.audio_queue.qsize()
    
    def get_stats(self):
        """Get receiver statistics"""
        stats = self.stats.copy()
        if stats['start_time']:
            elapsed = (datetime.now() - stats['start_time']).total_seconds()
            stats['elapsed_seconds'] = elapsed
            if elapsed > 0:
                stats['packets_per_second'] = stats['packets_received'] / elapsed
                stats['kbps'] = (stats['bytes_received'] * 8) / (elapsed * 1000)
        stats['queue_depth'] = self.get_queue_size()
        return stats


class AudioOutput:
    """
    Outputs audio data to system playback device using PyAudio.
    Intended for use with VB-Cable virtual microphone.
    """
    
    def __init__(self):
        self.pyaudio_instance = None
        self.stream = None
        self.running = False
        
    def start(self):
        """Initialize PyAudio and start output stream"""
        try:
            self.pyaudio_instance = pyaudio.PyAudio()
            
            # Open output stream
            self.stream = self.pyaudio_instance.open(
                format=pyaudio.paInt16,          # 16-bit PCM
                channels=AudioConfig.CHANNELS,    # Mono
                rate=AudioConfig.SAMPLE_RATE,     # 48kHz
                output=True,
                frames_per_buffer=AudioConfig.CHUNK_SIZE // 2,  # Convert bytes to samples
            )
            
            self.running = True
            print(f"[AUDIO] Output started: {AudioConfig.SAMPLE_RATE}Hz, {AudioConfig.BIT_DEPTH}-bit, {'mono' if AudioConfig.CHANNELS == 1 else 'stereo'}")
            
        except Exception as e:
            print(f"[ERROR] Failed to initialize audio output: {e}")
            raise
            
    def play_from_queue(self, audio_queue, stop_event):
        """Continuously play audio from queue"""
        while self.running and not stop_event.is_set():
            try:
                # Get audio data from queue (blocking with timeout)
                data = audio_queue.get(timeout=0.5)
                
                # Write to audio output
                if self.stream and self.running:
                    self.stream.write(data)
                    
            except queue.Empty:
                continue
            except Exception as e:
                if self.running:
                    print(f"[ERROR] Audio playback error: {e}")
                    
    def stop(self):
        """Stop audio output and cleanup"""
        self.running = False
        
        if self.stream:
            try:
                self.stream.stop_stream()
                self.stream.close()
            except:
                pass
            self.stream = None
            
        if self.pyaudio_instance:
            try:
                self.pyaudio_instance.terminate()
            except:
                pass
            self.pyaudio_instance = None


class WirelessMicClient:
    """
    Main client class that coordinates UDP reception and audio output.
    Provides console UI for status and control.
    """
    
    def __init__(self):
        self.receiver = UDPAudioReceiver()
        self.audio_output = AudioOutput()
        self.stop_event = threading.Event()
        self.output_thread = None
        
    def start(self):
        """Start the wireless mic client"""
        print("=" * 50)
        print("Wireless Microphone Windows Client")
        print("=" * 50)
        print(f"Audio Format: {AudioConfig.SAMPLE_RATE}Hz, {AudioConfig.BIT_DEPTH}-bit, Mono")
        print(f"UDP Port: {AudioConfig.PORT}")
        print(f"Max Queue Depth: {AudioConfig.MAX_QUEUE_SIZE} packets")
        print("-" * 50)
        
        # Start UDP listener
        self.receiver.start_udp_listener()
        
        # Start audio output
        try:
            self.audio_output.start()
            
            # Start playback thread
            self.output_thread = threading.Thread(
                target=self.audio_output.play_from_queue,
                args=(self.receiver.audio_queue, self.stop_event),
                daemon=True
            )
            self.output_thread.start()
            
            print("-" * 50)
            print("[OK] Client started successfully!")
            print("Commands: [s]tatus, [q]uit")
            print("-" * 50)
            
        except Exception as e:
            print(f"[ERROR] Failed to start: {e}")
            self.stop()
            return False
            
        return True
        
    def run_console_loop(self):
        """Main console input loop"""
        while not self.stop_event.is_set():
            try:
                cmd = input().strip().lower()
                
                if cmd == 'q' or cmd == 'quit':
                    print("\nShutting down...")
                    self.stop_event.set()
                    break
                elif cmd == 's' or cmd == 'status':
                    self.print_status()
                elif cmd:
                    print("Unknown command. Use [s]tatus or [q]uit")
                    
            except EOFError:
                break
            except KeyboardInterrupt:
                print("\nInterrupted!")
                self.stop_event.set()
                break
                
    def print_status(self):
        """Print current status statistics"""
        stats = self.receiver.get_stats()
        print("\n" + "=" * 40)
        print("STATUS")
        print("=" * 40)
        print(f"Packets Received: {stats['packets_received']}")
        print(f"Packets Dropped:  {stats['packets_dropped']}")
        print(f"Queue Depth:      {stats.get('queue_depth', 0)} / {AudioConfig.MAX_QUEUE_SIZE}")
        if stats.get('elapsed_seconds'):
            print(f"Elapsed Time:     {stats['elapsed_seconds']:.1f}s")
            print(f"Packets/sec:      {stats.get('packets_per_second', 0):.1f}")
            print(f"Bitrate:          {stats.get('kbps', 0):.1f} kbps")
        print("=" * 40)
        
    def stop(self):
        """Stop all components"""
        print("\nStopping components...")
        
        self.stop_event.set()
        self.receiver.stop()
        self.audio_output.stop()
        
        # Wait briefly for threads to finish
        time.sleep(0.5)
        
        # Print final stats
        stats = self.receiver.get_stats()
        print(f"\nFinal Statistics:")
        print(f"  Total Packets: {stats['packets_received']}")
        print(f"  Total Bytes:   {stats['bytes_received']}")
        print(f"  Dropped:       {stats['packets_dropped']}")


def main():
    """Entry point"""
    client = WirelessMicClient()
    
    if client.start():
        client.run_console_loop()
        client.stop()
        print("\nGoodbye!")
    else:
        print("\nFailed to start client.")
        sys.exit(1)


if __name__ == '__main__':
    main()
