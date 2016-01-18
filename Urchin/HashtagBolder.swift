/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import Foundation
import UIKit
import twitter_text

class HashtagBolder {
    
    // A function to identify, then bold, the hashtags in some text
    // returns an attributed string
    func boldHashtags(text: NSString) -> NSMutableAttributedString {
        let attributedText = NSMutableAttributedString(string: text as String)

        attributedText.addAttributes([NSFontAttributeName: mediumRegularFont, NSForegroundColorAttributeName: blackishColor], range: NSRange(location: 0, length: attributedText.length))
        
        let hashTags = TwitterText.hashtagsInText(text as String, checkingURLOverlap: false)
        for hashtag in hashTags {
            attributedText.addAttributes([NSFontAttributeName: mediumBoldFont], range: hashtag.range)
        }

        return attributedText
    }
    
}