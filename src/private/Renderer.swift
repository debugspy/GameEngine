//
//  GERenderer.swift
//  MKTest
//
//  Created by Anthony Green on 12/23/15.
//  Copyright © 2015 Anthony Green. All rights reserved.
//

import Foundation
import MetalKit

final class Renderer {
  private let commandQueue: MTLCommandQueue

  private let shapePipeline: ShapePipeline
  private let spritePipeline: SpritePipeline
  private let textPipeline: TextPipeline
  private let depthState: MTLDepthStencilState

  private let inflightSemaphore: dispatch_semaphore_t

  init(device: MTLDevice) {
    //not sure where to set this up or if I even want to do it this way
    Fonts.cache.device = device
    //-----------------------------------------------------------------

    commandQueue = device.newCommandQueue()
    commandQueue.label = "main command queue"

    //descriptorQueue = RenderPassQueue(view: view)
    
    let factory = PipelineFactory(device: device)
    shapePipeline = factory.constructShapePipeline()
    spritePipeline = factory.constructSpritePipeline()
    textPipeline = factory.constructTextPipeline()
    depthState = factory.constructDepthStencil()

    inflightSemaphore = dispatch_semaphore_create(BUFFER_SIZE)
  }

  func render(nextRenderPass: NextRenderPass, shapeNodes: [ShapeNode], spriteNodes: [SpriteNode], textNodes: [TextNode]) {
    dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)

    let commandBuffer = commandQueue.commandBuffer()
    commandBuffer.label = "Frame command buffer"

    if let (renderPassDescriptor, drawable) = nextRenderPass() {
      let encoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
      encoder.setDepthStencilState(depthState)
      //need to update the data I think
      //encoder.setFrontFacingWinding(.CounterClockwise)
      //encoder.setCullMode(.Back)

      shapePipeline.encode(encoder, nodes: shapeNodes)
      spritePipeline.encode(encoder, nodes: spriteNodes)
      textPipeline.encode(encoder, nodes: textNodes)

      encoder.endEncoding()

      commandBuffer.addCompletedHandler { _ in
        dispatch_semaphore_signal(self.inflightSemaphore)
      }

      commandBuffer.presentDrawable(drawable)
    }

    commandBuffer.commit()
  }

  deinit {
    (0..<BUFFER_SIZE).forEach { _ in
      dispatch_semaphore_signal(inflightSemaphore)
    }
  }
}
