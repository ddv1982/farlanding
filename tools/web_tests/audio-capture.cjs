function captureAudio() {
  const connect = AudioNode.prototype.connect;
  window.audioCapture = { rms: 0, chunks: [], recorder: null };
  AudioNode.prototype.connect = function(destination, ...args) {
    const result = connect.call(this, destination, ...args);
    if (destination === this.context.destination) {
      if (!window.audioCapture.recorder) {
        const analyser = this.context.createAnalyser();
        analyser.fftSize = 2048;
        const output = this.context.createMediaStreamDestination();
        connect.call(analyser, output);
        const recorder = new MediaRecorder(output.stream);
        window.audioCapture.recorder = recorder;
        window.audioCapture.analyser = analyser;
        window.audioCapture.context = this.context;
        recorder.ondataavailable = event => window.audioCapture.chunks.push(event.data);
        recorder.start(1000);
        const samples = new Float32Array(analyser.fftSize);
        setInterval(() => {
          analyser.getFloatTimeDomainData(samples);
          window.audioCapture.rms = Math.sqrt(samples.reduce((sum, value) => sum + value * value, 0) / samples.length);
        }, 100);
      }
      connect.call(this, window.audioCapture.analyser);
    }
    return result;
  };
}
module.exports = { captureAudio };
