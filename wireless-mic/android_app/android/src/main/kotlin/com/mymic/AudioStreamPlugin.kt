package com.mymic

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

/**
 * Flutter plugin for streaming microphone audio via EventChannel
 * Captures 48kHz, 16-bit, mono PCM audio and sends to Flutter
 */
class AudioStreamPlugin : FlutterPlugin, EventChannel.StreamHandler {
    
    companion object {
        private const val CHANNEL_NAME = "com.mymic/audio_stream"
        private const val SAMPLE_RATE = 48000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val BUFFER_SIZE_MULTIPLIER = 4
    }
    
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var context: Context? = null
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        eventChannel = EventChannel(binding.binaryMessenger, CHANNEL_NAME)
        eventChannel?.setStreamHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopRecording()
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startRecording()
    }
    
    override fun onCancel(arguments: Any?) {
        stopRecording()
        eventSink = null
    }
    
    /**
     * Start audio recording from microphone
     */
    private fun startRecording() {
        if (isRecording) return
        
        // Check microphone permission
        if (context == null || !hasMicrophonePermission()) {
            eventSink?.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }
        
        try {
            // Calculate minimum buffer size
            val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            val bufferSize = minBufferSize * BUFFER_SIZE_MULTIPLIER
            
            // Create AudioRecord instance
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )
            
            // Verify AudioRecord was created successfully
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                eventSink?.error("INIT_FAILED", "Failed to initialize AudioRecord", null)
                audioRecord = null
                return
            }
            
            // Start recording in background thread
            isRecording = true
            Thread {
                recordAudioLoop(bufferSize)
            }.start()
            
        } catch (e: SecurityException) {
            eventSink?.error("SECURITY_ERROR", e.message, null)
            isRecording = false
        } catch (e: Exception) {
            eventSink?.error("START_ERROR", e.message, null)
            isRecording = false
        }
    }
    
    /**
     * Main recording loop - continuously reads audio buffers and sends to Flutter
     */
    private fun recordAudioLoop(bufferSize: Int) {
        audioRecord?.startRecording()
        
        val buffer = ByteArray(bufferSize)
        
        while (isRecording) {
            try {
                val readSize = audioRecord?.read(buffer, 0, bufferSize) ?: -1
                
                if (readSize > 0) {
                    // Send audio data to Flutter via EventChannel
                    // Only send the actual read bytes
                    val audioData = buffer.copyOf(readSize)
                    
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(audioData)
                    }
                } else if (readSize == AudioRecord.ERROR_INVALID_OPERATION ||
                          readSize == AudioRecord.ERROR_BAD_VALUE) {
                    // Fatal error, stop recording
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.error("READ_ERROR", "AudioRecord read failed: $readSize", null)
                    }
                    break
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    eventSink?.error("READ_EXCEPTION", e.message, null)
                }
                break
            }
        }
    }
    
    /**
     * Stop audio recording and release resources
     */
    private fun stopRecording() {
        isRecording = false
        
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            // Ignore errors during cleanup
        } finally {
            audioRecord = null
        }
    }
    
    /**
     * Check if microphone permission is granted
     */
    private fun hasMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context!!,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
}
