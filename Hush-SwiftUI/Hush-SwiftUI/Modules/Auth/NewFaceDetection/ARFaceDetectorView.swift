//
//  ARFaceDetectorView.swift
//  Hush-SwiftUI
//
//  Created by Serge Vysotsky on 04.05.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import AVFoundation
import Vision

struct ARFaceDetectorView: UIViewControllerRepresentable {
    let mask: Mask?
    let maskEnabled: Bool
    let shouldTakeImage: Bool
    @Binding var capturedImage: UIImage?
    @Binding var sessionRunning: Bool
    
    func makeUIViewController(context: Context) -> FaceTrackingViewController {
        FaceTrackingViewController()
    }
    
    func updateUIViewController(_ faceTrackingViewController: FaceTrackingViewController, context: Context) {
        faceTrackingViewController.mask = mask
        faceTrackingViewController.maskEnabled = maskEnabled
        faceTrackingViewController.captureCompletion = shouldTakeImage ?
            { self.capturedImage = $0 } : nil
        
        if sessionRunning && faceTrackingViewController.session?.isRunning != true {
            faceTrackingViewController.viewDidLoad()
        }
        
        if !sessionRunning && faceTrackingViewController.session?.isRunning != false {
            faceTrackingViewController.session?.stopRunning()
            faceTrackingViewController.didReceiveMemoryWarning()
        }
    }
}

final class FaceTrackingViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    fileprivate var mask: Mask?
    fileprivate var maskEnabled = false
    fileprivate var captureCompletion: ((UIImage) -> Void)?
    
    // AVCapture variables to hold sequence data
    fileprivate var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var stillImageOutput = AVCapturePhotoOutput()
    private var videoDataOutputQueue: DispatchQueue?
    
    private var captureDevice: AVCaptureDevice?
    private var captureDeviceResolution: CGSize = CGSize()
    
    // Layer UI for drawing Vision results
    private var rootLayer: CALayer?
    private var detectionOverlayLayer: CALayer?
    private var detectedFaceRectangleShapeLayer: CAShapeLayer?
    private var detectedFaceLandmarksShapeLayer: CAShapeLayer?
    private let imageView = UIImageView()
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // MARK: UIViewController overrides
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session = setupAVCaptureSession()
        prepareVisionRequest()
        session?.startRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        detectionRequests?.forEach { $0.cancel() }
        detectionRequests?.removeAll()
        
        trackingRequests?.forEach { $0.cancel() }
        trackingRequests?.removeAll()
    }
    
    // MARK: AVCapture Setup
    
    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        do {
            let inputDevice = try self.configureFrontCamera(for: captureSession)
            configureVideoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            designatePreviewLayer(for: captureSession)
            return captureSession
        } catch let executionError as NSError {
            presentError(executionError)
        } catch {
            presentErrorAlert(message: "An unexpected failure has occured")
        }
        
        teardownAVCapture()
        return nil
    }
    
    /// - Tag: ConfigureDeviceResolution
    fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: String(describing: type(of: self)), code: 1, userInfo: nil)
    }
    
    /// - Tag: CreateSerialDispatchQueue
    fileprivate func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VisionFaceTrack")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
        self.captureDevice = inputDevice
        self.captureDeviceResolution = resolution
    }
    
//    func capturePhoto() {
//        //        takeScreenshot(true)
//        //        return
//        //        UIGraphicsBeginImageContextWithOptions(view.frame.size, true, 0)
//        //        guard let context = UIGraphicsGetCurrentContext() else { return }
//        //        view.layer.render(in: context)
//        //        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return }
//        //        UIGraphicsEndImageContext()
//        //
//        //        //Save it to the camera roll
//        //        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
//        //
//        //        return
//
//        let settings = AVCapturePhotoSettings()
//        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
//        let previewFormat = [
//            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
//            kCVPixelBufferWidthKey as String: 160,
//            kCVPixelBufferHeightKey as String: 160
//        ]
//        settings.previewPhotoFormat = previewFormat
//        stillImageOutput.capturePhoto(with: settings, delegate: self)
//    }
    
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
//        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
//                    let immg = UIImage(data: dataImage)!
////                    self.imgViewUser.image = immg.fixedOrientation()
////                    self.imgViewUser.isHidden = false
//                    //capturePhoto()
//                    imageView.image = screenshot
//
//        //            let vc = self.storyboard?.instantiateViewController(withIdentifier: "LookingGoodVC") as! LookingGoodVC
//        //            vc.userImage = img2
//        //            self.navigationController?.pushViewController(vc, animated: true)
////                    captureSession.stopRunning()
////                    completion?(img2)
//                }
//    }
    
    /// - Tag: DesignatePreviewLayer
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        if let previewRootLayer = self.view?.layer {
            self.rootLayer = previewRootLayer
            
            previewRootLayer.masksToBounds = true
            videoPreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(videoPreviewLayer)
        }
    }
    
    // Removes infrastructure for AVCapture as part of cleanup.
    fileprivate func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil
        
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    // MARK: Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(ok)
        present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    // MARK: Helper Methods for Handling Device Orientation & EXIF
    
    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    // MARK: Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                let results = faceDetectionRequest.results as? [VNFaceObservation]
            else { return }
            
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection.  Find face, then track it.
        detectionRequests = [faceDetectionRequest]
        sequenceRequestHandler = VNSequenceRequestHandler()
        setupVisionDrawingLayers()
    }
    
    // MARK: Drawing Vision Observations
    
    fileprivate func setupVisionDrawingLayers() {
        let captureDeviceResolution = self.captureDeviceResolution
        
        let captureDeviceBounds = CGRect(x: 0,
                                         y: 0,
                                         width: captureDeviceResolution.width,
                                         height: captureDeviceResolution.height)
        
        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
                                                     y: captureDeviceBounds.midY)
        
        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
        
        guard let rootLayer = self.rootLayer else {
            return presentErrorAlert(message: "view was not property initialized")
        }
        
        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        let faceRectangleShapeLayer = CAShapeLayer()
        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
        faceRectangleShapeLayer.bounds = captureDeviceBounds
        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
        faceRectangleShapeLayer.fillColor = nil
        faceRectangleShapeLayer.strokeColor = UIColor.green.withAlphaComponent(0.7).cgColor
        faceRectangleShapeLayer.lineWidth = 5
        faceRectangleShapeLayer.shadowOpacity = 0.7
        faceRectangleShapeLayer.shadowRadius = 5
        
        let faceLandmarksShapeLayer = CAShapeLayer()
        faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
        faceLandmarksShapeLayer.bounds = captureDeviceBounds
        faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
        faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
        faceLandmarksShapeLayer.fillColor = nil
        faceLandmarksShapeLayer.strokeColor = UIColor.yellow.withAlphaComponent(0.7).cgColor
        faceLandmarksShapeLayer.lineWidth = 3
        faceLandmarksShapeLayer.shadowOpacity = 0.7
        faceLandmarksShapeLayer.shadowRadius = 5
        
        overlayLayer.addSublayer(faceRectangleShapeLayer)
        faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
        rootLayer.addSublayer(overlayLayer)
        
        detectionOverlayLayer = overlayLayer
        detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
        detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer
        
        updateLayerGeometry()
    }
    
    fileprivate func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer,
            let rootLayer = self.rootLayer,
            let previewLayer = self.previewLayer
            else {
            return
        }
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        
        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
            
        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }
        
        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
            .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        
        // Cover entire screen UI.
        let rootLayerBounds = rootLayer.bounds
        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
    }
    
    fileprivate func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath, applying affineTransform: CGAffineTransform, closingWhenComplete closePath: Bool) {
        let pointCount = landmarkRegion.pointCount
        if pointCount > 1 {
            let points: [CGPoint] = landmarkRegion.normalizedPoints
            path.move(to: points[0], transform: affineTransform)
            path.addLines(between: points, transform: affineTransform)
            if closePath {
                path.addLine(to: points[0], transform: affineTransform)
                path.closeSubpath()
            }
        }
    }
    
    lazy var screenImageView: UIImageView = {
        let imvw = UIImageView()
        imvw.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imvw)
        
        NSLayoutConstraint.activate([
            view.trailingAnchor.constraint(equalTo: imvw.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: imvw.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: imvw.leadingAnchor),
            view.topAnchor.constraint(equalTo: imvw.topAnchor),
//            imvw.widthAnchor.constraint(equalToConstant: 100),
//            imvw.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        imvw.contentMode = .scaleAspectFill
        return imvw
    }()
    
    
    
    fileprivate func addIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
        let displaySize = self.captureDeviceResolution
        
        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
//        faceRectanglePath.addRect(faceBounds)
        
        if let landmarks = faceObservation.landmarks {
            // Landmarks are relative to -- and normalized within --- face bounds
//            let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y)
//                .scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
//
//            // Treat eyebrows and lines as open-ended regions when drawing paths.
//            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEyebrow,
//                landmarks.rightEyebrow,
//                landmarks.faceContour,
//                landmarks.noseCrest,
//                landmarks.medianLine,
//            ]
//            for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
//                self.addPoints(in: openLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
//            }
//
//            // Draw eyes, lips, and nose as closed regions.
//            let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEye,
//                landmarks.rightEye,
//                landmarks.outerLips,
//                landmarks.innerLips,
//                landmarks.nose,
//            ]
//            for closedLandmarkRegion in closedLandmarkRegions where closedLandmarkRegion != nil {
//                self.addPoints(in: closedLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: true)
//            }
//
//            func drawPupil(_ pupil: CGPoint) {
//                let size = CGFloat(0.1)
//                let rect = CGRect(origin: pupil, size: CGSize(width: size, height: size)).offsetBy(dx: -size / 2, dy: -size / 2)
//                faceLandmarksPath.addEllipse(in: rect, transform: affineTransform)
//            }
            
            if let leftPupil = landmarks.leftPupil?.normalizedPoints.first,
                let rightPupil = landmarks.rightPupil?.normalizedPoints.first {
                
//                drawPupil(leftPupil)
//                drawPupil(rightPupil)
                
                let angle = atan((leftPupil.y - rightPupil.y) / (leftPupil.x - rightPupil.x))
                if maskEnabled, let maskImage = mask?.image, let category = mask?.category {
                    let insets: UIEdgeInsets
                    switch category {
                    case .ball:
                        let v: CGFloat = 500
                        let h: CGFloat = 200
                        insets = UIEdgeInsets(top: v, left: -h, bottom: -v, right: -h)
                    case .funny:
                        let v: CGFloat = 300
                        let h: CGFloat = 200
                        insets = UIEdgeInsets(top: v, left: -h, bottom: -v, right: -h)
                    case .glasses:
                        let v: CGFloat = 200
                        let h: CGFloat = 100
                        insets = UIEdgeInsets(top: v, left: -h, bottom: -v, right: -h)
                    case .ancient:
                        let v: CGFloat = 350
                        let h: CGFloat = 50
                        insets = UIEdgeInsets(top: -v / 4, left: -h, bottom: -v, right: -h)
                    }
                    
                    imageView.frame = faceBounds.inset(by: insets)
                    
                    imageView.layer.removeFromSuperlayer()
                    imageView.image = maskImage.rotate(radians: -angle)
                    imageView.contentMode = .scaleAspectFill
                    imageView.transform = detectionOverlayLayer!.affineTransform().inverted()
                    detectionOverlayLayer!.addSublayer(imageView.layer)
                    
                    if let completion = captureCompletion, let screenshot = screenshot {
                        screenImageView.image = screenshot
                        session?.stopRunning()
                        completion(screenshot)
                        captureCompletion = nil
                    }
                } else {
                    imageView.layer.removeFromSuperlayer()
                    if let completion = captureCompletion, let screenshot = screenshot {
                       screenImageView.image = screenshot
                       session?.stopRunning()
                       completion(screenshot)
                       captureCompletion = nil
                   }
                }
            }
        }
    }
    
    private var lastCaptureImage: UIImage?
    private let screenshotLayer = CALayer()
    private var screenshot: UIImage? {
        guard let lastCaptureImage = lastCaptureImage else { return nil }
        
        let imageView = UIImageView(image: lastCaptureImage)
        imageView.contentMode = .scaleAspectFill
        imageView.frame = view.bounds
        
        screenshotLayer.frame = detectionOverlayLayer!.bounds
        screenshotLayer.addSublayer(imageView.layer)
        screenshotLayer.addSublayer(detectionOverlayLayer!)
        
        UIGraphicsBeginImageContext(view.bounds.size)
        let context = UIGraphicsGetCurrentContext()!
        
        screenshotLayer.render(in: context)
        
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return screenshot
    }
    
    /// - Tag: DrawPaths
    fileprivate func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
            let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
            else {
            return
        }
        
        CATransaction.begin()
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let faceRectanglePath = CGMutablePath()
        let faceLandmarksPath = CGMutablePath()
        
        for faceObservation in faceObservations {
            self.addIndicators(to: faceRectanglePath,
                               faceLandmarksPath: faceLandmarksPath,
                               for: faceObservation)
        }
        
        faceRectangleShapeLayer.path = faceRectanglePath
        faceLandmarksShapeLayer.path = faceLandmarksPath
        
        self.updateLayerGeometry()
        
        CATransaction.commit()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                     on: pixelBuffer,
                                                     orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // Nothing to track, so abort.
            return
        }
        
        // Perform face landmark tracking on detected faces.
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // Perform landmark detection on tracked faces.
        for trackingRequest in newTrackingRequests {
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                    let results = landmarksRequest.results as? [VNFaceObservation] else {
                        return
                }
                
                // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
                DispatchQueue.main.async {
                    self.drawFaceObservations(results)
                    
                    let ciImg = CIImage(cvPixelBuffer: pixelBuffer)
                    let imgWidth = ciImg.extent.width
                    let imgHeight = ciImg.extent.height
                    let rec = CGRect(x: 0, y: 0, width: imgHeight, height: imgWidth)
                    if let cgImage = CIContext().createCGImage(ciImg.oriented(.leftMirrored), from: rec) {
                        self.lastCaptureImage = UIImage(cgImage: cgImage)
                    }
                    
//                    self.lastCaptureImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            
            // Continue to track detected facial landmarks.
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
            }
        }
    }
}

extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
//        UIGraphicsBeginImageContext(rotatedSize)
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, UIScreen.main.scale)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0,
                                 y: rotatedSize.height / 2.0)
            
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            
            let imageRect = CGRect(x: -origin.x, y: -origin.y, width: rotatedSize.width, height: rotatedSize.height)
            let drawRect = ResizingBehavior.aspectFit.apply(
                rect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                target: imageRect)
            
            draw(in: drawRect)
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return rotatedImage ?? self
        }

        return self
    }
    
    enum ResizingBehavior: Int {
        case aspectFit /// The content is proportionally resized to fit into the target rectangle.
        case aspectFill /// The content is proportionally resized to completely fill the target rectangle.
        case stretch /// The content is stretched to match the entire target rectangle.
        case center /// The content is centered in the target rectangle, but it is NOT resized.

        public func apply(rect: CGRect, target: CGRect) -> CGRect {
            if rect == target || target == CGRect.zero {
                return rect
            }

            var scales = CGSize.zero
            scales.width = abs(target.width / rect.width)
            scales.height = abs(target.height / rect.height)

            switch self {
                case .aspectFit:
                    scales.width = min(scales.width, scales.height)
                    scales.height = scales.width
                case .aspectFill:
                    scales.width = max(scales.width, scales.height)
                    scales.height = scales.width
                case .stretch:
                    break
                case .center:
                    scales.width = 1
                    scales.height = 1
            }

            var result = rect.standardized
            result.size.width *= scales.width
            result.size.height *= scales.height
            result.origin.x = target.minX + (target.width - result.width) / 2
            result.origin.y = target.minY + (target.height - result.height) / 2
            return result
        }
    }
}
