package `in`.itfixer199.agent

class AudioEngine {
    companion object {
        init {
            System.loadLibrary("native-lib")
        }
    }

    external fun generateSineWave(frequency: Float, sampleRate: Int, durationInSeconds: Int): ShortArray
}

