//
//  RotationDial.swift
//
//  Created by Echo on 10/21/18.
//  Copyright © 2018 Echo. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit

@IBDesignable
final class RotationDial: UIView {
    var isAttachedToCropView = true
    
    var pointerHeight: CGFloat = 8
    var spanBetweenDialPlateAndPointer: CGFloat = 6
    var pointerWidth: CGFloat = 8 * sqrt(2)
    
    var didUpdateRotationValue: (_ angle: Angle) -> Void = { _ in }
    var didFinishRotation: () -> Void = { }
    
    var viewModel: RotationDialViewModelProtocol
    
    private var config: RotationDialConfig
    
    private var angleLimit = Angle(radians: .pi)
    private var showRadiansLimit: CGFloat = .pi
    private var dialPlate: RotationDialPlate?
    private var dialPlateHolder: UIView?
    private var pointer: CAShapeLayer = CAShapeLayer()
    
    init(frame: CGRect,
         config: RotationDialConfig,
         viewModel: RotationDialViewModelProtocol,
         dialPlate: RotationDialPlate) {
        self.config = config
        self.viewModel = viewModel
        self.dialPlate = dialPlate
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func accessibilityIncrement() {
        viewModel.rotationAngle = Angle(degrees: 1)
        setAccessibilityValue()
    }
    
    override func accessibilityDecrement() {
        viewModel.rotationAngle = Angle(degrees: -1)
        setAccessibilityValue()
    }
}

// MARK: - private functions
extension RotationDial {
    private func setupUI() {
        clipsToBounds = true
        backgroundColor = config.backgroundColor
        setAccessibilities()
        
        dialPlateHolder?.removeFromSuperview()
        dialPlateHolder = getDialPlateHolder(by: config.orientation)
        addSubview(dialPlateHolder!)
        setupDialPlate(in: dialPlateHolder!)
        setupPointer(in: dialPlateHolder!)
        setDialPlateHolder(by: config.orientation)
    }
    
    private func setupViewModel() {
        viewModel.didSetRotationAngle = { [weak self] angle in
            self?.handleRotation(by: angle)
        }
        viewModel.setup(with: getRotationCenter())
    }
    
    private func handleRotation(by angle: Angle) {
        if case .limit = config.rotationLimitType {
            guard angle <= angleLimit else {
                return
            }
        }
        
        if updateRotationValue(by: angle) {
            let newAngle = getRotationAngle()
            didUpdateRotationValue(newAngle)
        }
    }
    
    private func getDialPlateHolder(by orientation: RotationDialConfig.Orientation) -> UIView {
        let view = UIView(frame: bounds)
        
        switch orientation {
        case .normal, .upsideDown:
            ()
        case .left, .right:
            view.frame.size = CGSize(width: view.bounds.height, height: view.bounds.width)
        }
        
        return view
    }
    
    private func setDialPlateHolder(by orientation: RotationDialConfig.Orientation) {
        switch orientation {
        case .normal:
            ()
        case .left:
            dialPlateHolder?.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
            dialPlateHolder?.frame.origin = CGPoint(x: 0, y: 0)
        case .right:
            dialPlateHolder?.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            dialPlateHolder?.frame.origin = CGPoint(x: 0, y: 0)
        case .upsideDown:
            dialPlateHolder?.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
            dialPlateHolder?.frame.origin = CGPoint(x: 0, y: 0)
        }
    }
    
    private func setupDialPlate(in container: UIView) {
        var margin = CGFloat(config.margin)
        
        if case .limit(let degreeAngle) = config.angleShowLimitType {
            margin = 0
            showRadiansLimit = Angle(degrees: degreeAngle).radians
        } else {
            showRadiansLimit = CGFloat.pi
        }
        
        var dialPlateShowHeight = container.frame.height - margin - pointerHeight - spanBetweenDialPlateAndPointer
        var radius = dialPlateShowHeight / (1 - cos(showRadiansLimit))
        
        if radius * 2 * sin(showRadiansLimit) > container.frame.width {
            radius = (container.frame.width / 2) / sin(showRadiansLimit)
            dialPlateShowHeight = radius - radius * cos(showRadiansLimit)
        }
        
        let dialPlateLength = 2 * radius
        let dialPlateFrame = CGRect(x: (container.frame.width - dialPlateLength) / 2,
                                    y: margin - (dialPlateLength - dialPlateShowHeight),
                                    width: dialPlateLength,
                                    height: dialPlateLength)
        
        dialPlate?.removeFromSuperview()
        dialPlate?.setup(with: dialPlateFrame)
        container.addSubview(dialPlate!)
    }
    
    private func setupPointer(in container: UIView) {
        guard let dialPlate = dialPlate else { return }
        
        let path = CGMutablePath()
        let pointerEdgeLength: CGFloat = pointerWidth
        
        let pointTop = CGPoint(x: container.bounds.width/2, y: dialPlate.frame.maxY + spanBetweenDialPlateAndPointer)
        let pointLeft = CGPoint(x: container.bounds.width/2 - pointerEdgeLength / 2, y: pointTop.y + pointerHeight)
        let pointRight = CGPoint(x: container.bounds.width/2 + pointerEdgeLength / 2, y: pointLeft.y)
        
        path.move(to: pointTop)
        path.addLine(to: pointLeft)
        path.addLine(to: pointRight)
        path.addLine(to: pointTop)
        pointer.fillColor = config.indicatorColor.cgColor
        pointer.path = path
        container.layer.addSublayer(pointer)
    }
    
    private func getRotationCenter() -> CGPoint {
        guard let dialPlate = dialPlate else { return .zero }
        
        if case .custom(let center) = config.rotationCenterType {
            return center
        } else {
            let point = CGPoint(x: dialPlate.bounds.midX, y: dialPlate.bounds.midY)
            return dialPlate.convert(point, to: self)
        }
    }
}

extension RotationDial: RotationDialProtocol {
    func setupUI(withAllowableFrame allowableFrame: CGRect) {
        self.frame = allowableFrame
        
        if case .limit(let degreeAngle) = config.rotationLimitType {
            angleLimit = Angle(degrees: degreeAngle)
        }
        
        setupUI()
        setupViewModel()
    }
    
    @discardableResult
    func updateRotationValue(by angle: Angle) -> Bool {
        guard let dialPlate = dialPlate else { return false }
        
        let radians = angle.radians
        if case .limit = config.rotationLimitType {
            if (getRotationAngle() * angle).radians >= 0 && abs(getRotationAngle().radians + radians) > angleLimit.radians {
                
                if radians > 0 {
                    rotateDialPlate(to: angleLimit)
                } else {
                    rotateDialPlate(to: -angleLimit)
                }
                
                return false
            }
        }
        
        dialPlate.transform = dialPlate.transform.rotated(by: radians)
        setAccessibilityValue()
        
        return true
    }
    
    func rotateDialPlate(to angle: Angle, animated: Bool = false) {
        let radians = angle.radians
        
        if case .limit = config.rotationLimitType {
            guard abs(radians) <= angleLimit.radians else {
                return
            }
        }
        
        func rotate() {
            dialPlate?.transform = CGAffineTransform(rotationAngle: radians)
        }
        
        if animated {
            UIView.animate(withDuration: 0.5) {
                rotate()
            }
        } else {
            rotate()
        }
    }
    
    func getRotationAngle() -> Angle {
        guard let dialPlate = dialPlate else { return Angle(degrees: 0) }        
        return dialPlate.getRotationAngle()
    }
    
    func setRotationCenter(by point: CGPoint, of view: UIView) {
        let newPoint = view.convert(point, to: self)
        config.rotationCenterType = .custom(center: newPoint)
    }
    
    func reset() {
        transform = .identity
        dialPlate?.reset()
        config.rotationCenterType = .useDefault
    }
    
    func getLengthRatio() -> CGFloat {
        config.lengthRatio
    }
    
    func getTotalRotationValue() -> CGFloat {
        getRotationAngle().degrees
    }
}
