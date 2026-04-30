import MetalKit

final class EDROverlayView: MTKView, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue?

    init(frame: CGRect) {
        let device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        super.init(frame: frame, device: device)

        delegate = self
        autoResizeDrawable = false
        drawableSize = CGSize(width: 1, height: 1)
        colorPixelFormat = .rgba16Float
        colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        clearColor = MTLClearColorMake(16, 16, 16, 1)
        preferredFramesPerSecond = 5

        if let layer = layer as? CAMetalLayer {
            layer.wantsExtendedDynamicRangeContent = true
            layer.pixelFormat = .rgba16Float
            layer.isOpaque = false
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func draw(in view: MTKView) {
        guard
            let commandQueue,
            let renderPassDescriptor = currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let drawable = currentDrawable
        else {
            return
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
