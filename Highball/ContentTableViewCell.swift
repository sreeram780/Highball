//
//  ContentTableViewCell.swift
//  Highball
//
//  Created by Ian Ynda-Hummel on 8/28/14.
//  Copyright (c) 2014 ianynda. All rights reserved.
//

import UIKit
import Cartography
import DTCoreText
import FLAnimatedImage
import PINRemoteImage
import WCFastCell

class ContentTableViewCell: WCFastCell, DTAttributedTextContentViewDelegate {
	private(set) var usernameLabel: UILabel!
	private(set) var contentTextView: DTAttributedTextContentView!
	var width: CGFloat = 375
	var username: String? {
		didSet {
			usernameLabel.text = username
		}
	}
	var content: String? {
		didSet {
			if let content = content {
				let data = content.dataUsingEncoding(NSUTF8StringEncoding)
				let stringBuilderOptions = [DTDefaultHeadIndent: 0, DTDefaultFirstLineHeadIndent: 0]
				let htmlStringBuilder = DTHTMLAttributedStringBuilder(HTML: data, options: stringBuilderOptions, documentAttributes: nil)
				let attributedString = htmlStringBuilder.generatedAttributedString()
				contentTextView.attributedString = attributedString
				usernameLabel.superview?.hidden = (content.characters.count == 0)
			} else {
				contentTextView.attributedString = NSAttributedString(string: "")
				usernameLabel.superview?.hidden = true
			}
		}
	}

	var linkHandler: ((NSURL) -> ())?
	var widthDidChange: ((url: String, width: CGFloat, height: CGFloat) -> ())?
	var widthForURL: ((url: String) -> CGFloat?)?

	override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setUpCell()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setUpCell()
	}

	func setUpCell() {
		let usernameContainerView = UIView()

		usernameLabel = UILabel()
		contentTextView = DTAttributedTextContentView()

		usernameContainerView.backgroundColor = UIColor.blackColor()

		usernameLabel.font = UIFont.boldSystemFontOfSize(16)
		usernameLabel.textColor = UIColor.whiteColor()

		contentTextView.delegate = self

		usernameContainerView.addSubview(usernameLabel)
		contentView.addSubview(usernameContainerView)
		contentView.addSubview(contentTextView)

		constrain([usernameContainerView, usernameLabel, contentTextView, contentView]) { views in
			let usernameContainerView = views[0]
			let usernameLabel = views[1]
			let contentTextView = views[2]
			let contentView = views[3]

			usernameContainerView.top == contentView.top
			usernameContainerView.right <= contentView.right
			usernameContainerView.left == contentView.left
			usernameContainerView.height == 24 ~ 750

			usernameLabel.edges == inset(usernameContainerView.edges, 10, 4)

			contentTextView.top == usernameContainerView.bottom + 4
			contentTextView.right == contentView.right - 10
			contentTextView.bottom == contentView.bottom - 4 ~ 750
			contentTextView.left == contentView.left + 10
		}
	}

	override func prepareForReuse() {
		username = nil
		content = nil
		widthDidChange = nil
		widthForURL = nil
	}

	func attributedTextContentView(attributedTextContentView: DTAttributedTextContentView!, viewForAttachment attachment: DTTextAttachment!, frame: CGRect) -> UIView! {
		if let attachment = attachment as? DTImageTextAttachment {
			let imageView = FLAnimatedImageView(frame: frame)
			imageView.pin_setImageFromURL(attachment.contentURL) { result in
				if let image = result.image {
					self.imageView(imageView, withURL: attachment.contentURL, didChangeImageSize: image.size)
				} else if let animatedImage = result.animatedImage {
					self.imageView(imageView, withURL: attachment.contentURL, didChangeImageSize: animatedImage.size)
				}
			}
			return imageView
		}
		return nil
	}

	func attributedTextContentView(attributedTextContentView: DTAttributedTextContentView!, shouldDrawBackgroundForTextBlock textBlock: DTTextBlock!, frame: CGRect, context: CGContext!, forLayoutFrame layoutFrame: DTCoreTextLayoutFrame!) -> Bool {
		let rect = CGRect(x: frame.origin.x, y: frame.origin.y, width: 2, height: frame.height)
		let path = UIBezierPath(rect: rect)

		CGContextSetFillColorWithColor(context, UIColor.grayColor().CGColor)
		CGContextAddPath(context, path.CGPath)
		CGContextFillPath(context)

		return false
	}


	func imageView(imageView: FLAnimatedImageView, withURL url: NSURL, didChangeImageSize size: CGSize) {
		let pred = NSPredicate(format: "contentURL == %@", url)

		// update all attachments that matching this URL
		if let attachments = contentTextView.layoutFrame?.textAttachmentsWithPredicate(pred) as? [DTTextAttachment] {
			for attachment in attachments {
				let width = widthForURL?(url: attachment.contentURL.absoluteString) ?? min(size.width, self.width - 20)
				let scaledSize = CGSize(width: width, height: floor(size.height * width / size.width))
				attachment.originalSize = size
				attachment.displaySize = scaledSize

				widthDidChange?(url: attachment.contentURL.absoluteString, width: scaledSize.width, height: scaledSize.height)
			}
		}

		// need to reset the layouter because otherwise we get the old framesetter or cached layout frames
		contentTextView.layouter = nil

		// here we're layouting the entire string,
		// might be more efficient to only relayout the paragraphs that contain these attachments
		contentTextView.relayoutText()
	}
}
