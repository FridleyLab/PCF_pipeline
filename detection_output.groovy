import qupath.lib.projects.ProjectImageEntry
import qupath.lib.gui.scripting.QPEx
import qupath.lib.objects.PathObjects

def project = QPEx.getProject()
if (project == null) {
    print "❌ No project open!"
    return
}

def exportDir = new File(project.getBaseDirectory(), "../results") // "../" reads sibling folder
if (!exportDir.exists()) exportDir.mkdirs()

def exportFile = new File(exportDir, "QuPath_data.csv")
def entries = project.getImageList()
def headerWritten = false

exportFile.withWriter { writer ->
    entries.eachWithIndex { entry, i ->
        print "\nProcessing image ${i+1}/${entries.size()}: ${entry.getImageName()}"

        def imageData = entry.readImageData()
        def hierarchy = imageData.getHierarchy()
        def detections = hierarchy.getDetectionObjects().toList()

        if (detections.isEmpty()) {
            print "  No detections found, skipping..."
            imageData = null
            return
        }

        // --- Calibration for µm conversion ---
        def cal = imageData.getServer().getPixelCalibration()
        double pixelWidthMicrons  = cal.getPixelWidthMicrons()
        double pixelHeightMicrons = cal.getPixelHeightMicrons()

        if (Double.isNaN(pixelWidthMicrons) || Double.isNaN(pixelHeightMicrons) ||
            pixelWidthMicrons <= 0 || pixelHeightMicrons <= 0) {
            print "  ⚠️ Pixel calibration not available (µm). Centroids will be exported in pixels instead."
            pixelWidthMicrons  = 1.0
            pixelHeightMicrons = 1.0
        }

        // Measurement names from first detection
        def measNames = detections[0].getMeasurementList().getMeasurementNames()

        // Write header (once)
        if (!headerWritten) {
            // Add centroid columns explicitly (they are not in MeasurementList)
            writer.writeLine("Image,Parent,ID,CentroidX µm,CentroidY µm," + measNames.join(","))
            headerWritten = true
        }

        // Export each detection
        detections.eachWithIndex { det, idx ->
            def parent = det.getParent()
            def parentName = ""

            // Detect if the parent is an annotation
            if (parent != null && parent.getClass().getSimpleName().contains("Annotation")) {
                parentName = parent.getName() ?: ""
            }

            // --- Compute centroid from ROI ---
            def roi = det.getROI()
            double cx_px = Double.NaN
            double cy_px = Double.NaN

            if (roi != null) {
                // ROI centroid in pixel coordinates (QuPath uses pixel units for ROI coords)
                cx_px = roi.getCentroidX()
                cy_px = roi.getCentroidY()
            }

            // Convert to µm
            double cx_um = (Double.isNaN(cx_px)) ? Double.NaN : cx_px * pixelWidthMicrons
            double cy_um = (Double.isNaN(cy_px)) ? Double.NaN : cy_px * pixelHeightMicrons

            // Measurement values
            def mList = det.getMeasurementList()
            def vals = measNames.collect { name ->
                def v = mList[name]
                return v == null ? "" : v
            }

            // Write row
            def cxOut = Double.isNaN(cx_um) ? "" : cx_um
            def cyOut = Double.isNaN(cy_um) ? "" : cy_um

            writer.writeLine("${entry.getImageName()},${parentName},${idx+1},${cxOut},${cyOut}," + vals.join(","))
        }

        imageData = null
        System.gc()
    }
}

print "\n✅ Export complete!"
print "\nSaved to: ${exportFile.getCanonicalPath()}"