//
//  FLAnimatedImageView+GIFs.swift
//  Highball
//
//  Created by Ian Ynda-Hummel on 1/25/15.
//  Copyright (c) 2015 ianynda. All rights reserved.
//

import Foundation

private let imageLoadQueue = dispatch_queue_create("imageLoadQueue", nil)

extension FLAnimatedImageView {
    func setImageByTypeWithURL(imageURL: NSURL, completion: ((Bool) -> ())?) -> (SDWebImageOperation?) {
        let imageManager = SDWebImageManager.sharedManager()
        let imageDownloader = SDWebImageDownloader.sharedDownloader()
        let cacheKey = imageManager.cacheKeyForURL(imageURL)

        if imageURL.pathExtension == "gif" {
            if let animatedImage = AnimatedImageCache.animatedImageForKey(cacheKey) {
                self.animatedImage = animatedImage
                if let completion = completion {
                    completion(true)
                }
            } else if let data = TMCache.sharedCache().objectForKey(imageURL.absoluteString) as? NSData {
                dispatch_async(imageLoadQueue, {
                    let animatedImage = FLAnimatedImage(animatedGIFData: data)
                    if let animatedImage = animatedImage {
                        AnimatedImageCache.setAnimatedImage(animatedImage, forKey: cacheKey)
                        dispatch_async(dispatch_get_main_queue(), {
                            self.animatedImage = animatedImage
                            if let completion = completion {
                                completion(true)
                            }
                        })
                    } else {
                        dispatch_async(dispatch_get_main_queue()) {
                            if let completion = completion {
                                completion(false)
                            }
                        }
                    }
                })
            } else {
                return imageDownloader.downloadImageWithURL(imageURL, options: SDWebImageDownloaderOptions.UseNSURLCache, progress: nil, completed: { (image, data, error, finished) -> Void in
                    if finished && error == nil {
                        dispatch_async(imageLoadQueue, {
                            let animatedImage = FLAnimatedImage(animatedGIFData: data)
                            if let animatedImage = animatedImage {
                                AnimatedImageCache.setAnimatedImage(animatedImage, forKey: cacheKey)
                                dispatch_async(dispatch_get_main_queue(), {
                                    if let completion = completion {
                                        completion(true)
                                    }
                                    self.animatedImage = animatedImage
                                })
                            } else {
                                dispatch_async(dispatch_get_main_queue()) {
                                    if let completion = completion {
                                        completion(false)
                                    }
                                }
                            }
                        })
                        TMCache.sharedCache().setObject(data, forKey: imageURL.absoluteString)
                    } else {
                        if let completion = completion {
                            completion(false)
                        }
                    }
                })
            }
        } else {
            self.sd_setImageWithURL(imageURL) { image, error, cacheType, url in
                if let completion = completion {
                    completion(image != nil)
                }
            }
        }

        return nil
    }
}
