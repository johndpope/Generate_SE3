/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ARSCNViewDelegate interactions for `ViewController`.
*/

import ARKit
import os.log
import CoreGraphics

extension ViewController: ARSCNViewDelegate {
    // MARK: - ARSCNViewDelegate
  
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        var outMessage = String()
      
        if let camera = session.currentFrame?.camera{
          let translation = camera.transform.translation.debugDescription
          outMessage += "Trans: " + translation + ", "
        
          let eulerAngles = camera.eulerAngles.debugDescription
          outMessage += "(R,P,Y): " + eulerAngles
          
          // Have to update UI in Main Thread
          DispatchQueue.main.async {
          self.messageLabel_SE3.text = outMessage
          }
          
        }
        else {
            os_log("renderer: %@", log: self.oslog, type: .fault, "ARCamera not available")
        }

        updateFocusSquare()
        
        // If light estimation is enabled, update the intensity of the model's lights and the environment map
        if let lightEstimate = session.currentFrame?.lightEstimate {
            sceneView.scene.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40, queue: serialQueue)
        } else {
            sceneView.scene.enableEnvironmentMapWithIntensity(40, queue: serialQueue)
        }
      
        if(self.isCapturing){
        
          if let currentFrame = session.currentFrame{
          
            // Will be executed aynchronously inside of visionManager
            self.visionManager.writeARFrameToDisk(frame: currentFrame, id: self.frameCounter)
            self.frameCounter += 1
          }
          else {
            os_log("Renderer: %@", log: self.oslog, type: .fault, "Unable to extract ARFrame from Session")
          }
      
          
    } // END IF IS CAPTURING
  } // END RENDER UPDATE
  
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        serialQueue.async {
            self.addPlane(node: node, anchor: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        serialQueue.async {
            self.updatePlane(anchor: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        serialQueue.async {
            self.removePlane(anchor: planeAnchor)
        }
    }
  
  
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable:
            fallthrough
        case .limited:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
        displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        textManager.blurBackground()
        textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        textManager.unblurBackground()
        session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
        restartExperience(self)
        textManager.showMessage("RESETTING SESSION")
    }
}
