import qupath.ext.stardist.StarDist2D
import qupath.lib.gui.scripting.QPEx
import java.util.concurrent.Executors
import java.util.concurrent.Callable
import java.util.concurrent.TimeUnit
import java.time.Instant
import java.time.Duration

// ---------------- USER SETTINGS ----------------
def modelPath = buildFilePath(
    PROJECT_BASE_DIR,
    '..', '..', '..',
    '_common', 'QuPath',
    'dsb2018_heavy_augment.pb') // model inside _common/QuPath folder (ADJUST IF MOVING PILOT FOLDERS)
def nucChannel = 'DAPI'         // must match channel label exactly
def pLow = 2; def pHigh = 98    // normalization percentiles (robust against faint background)
def threshold = 0.5             // increase to suppress faint detections
def pixelSize = 0.6             // larger = faster; use 0.5–0.8 depending on nuclei size
def cellExpand = 3              // smaller = fewer geometry issues
int nThreads = 12               // reduce if you see memory pressure
// ------------------------------------------------

// Close any open image to avoid UI vs. batch state conflicts
try { QPEx.closeImage() } catch (Throwable ignore) {}

def project = QPEx.getProject()
def entries = project.getImageList()
println "Parallel StarDist on ${entries.size()} images with ${nThreads} threads (annotations only)…"

def executor = Executors.newFixedThreadPool(nThreads)
def tasks = []

entries.each { entry ->
  tasks << (Callable) {
    def start = Instant.now()
    def tid = Thread.currentThread().getName()
    println "[START] ${entry.getImageName()} on ${tid} @ ${start}"

    try {
      // Portable open (no GUI dependency)
      def imageData = entry.readImageData()
      QPEx.setBatchProjectAndImage(project, imageData)

      // Fetch annotations directly from the image's hierarchy (annotations only workflow)
      def annots = imageData.getHierarchy().getAnnotationObjects()
      if (annots == null || annots.isEmpty()) {
        println "  SKIP (no annotations): ${entry.getImageName()}"
        try { entry.saveImageData(imageData) } catch (Throwable t1) { try { QPEx.saveProject() } catch (Throwable t2) {} }
        imageData.close()
      } else {
        // Build detector per task (thread-safe)
        def stardist = StarDist2D.builder(modelPath)
            .channels(nucChannel)
            .normalizePercentiles(pLow, pHigh)
            .threshold(threshold)
            .pixelSize(pixelSize)
            .cellExpansion(cellExpand)
            .measureShape()
            .measureIntensity()
            .build()

        // Optional: clear previous detections
        try { QPEx.removeDetections() } catch (Throwable ignore) {}

        // Detect within existing annotations only
        stardist.detectObjects(imageData, annots)

        // Save results (version-tolerant)
        boolean saved = false
        try {
          entry.saveImageData(imageData)   // Preferred for 0.4/0.5
          saved = true
        } catch (Throwable t1) {
          try { QPEx.saveProject(); saved = true } catch (Throwable t2) {
            println "  WARN: Could not save via entry.saveImageData() or QPEx.saveProject()."
          }
        }

        imageData.close()
      }

    } catch (Throwable t) {
      println "FAILED: ${entry.getImageName()} — ${t.getMessage()}"
    }

    def end = Instant.now()
    println "[DONE ] ${entry.getImageName()} on ${tid} — ${Duration.between(start, end).toMinutes()} min"
    return null
  }
}

// Submit & wait for completion
def futures = tasks.collect { executor.submit(it) }
futures.each { it.get() }            // block until each finishes
executor.shutdown()
executor.awaitTermination(7, TimeUnit.DAYS)

// Save project state (belt & suspenders)
try { QPEx.saveProject() } catch (Throwable ignore) {}
println "All tasks finished."