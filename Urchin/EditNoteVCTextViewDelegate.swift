//
//  EditNoteVCTextViewDelegate.swift
//  urchin
//
//  Created by Ethan Look on 7/27/15.
//  Copyright (c) 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

extension EditNoteViewController: UITextViewDelegate {
    
    func textViewDidChange(textView: UITextView) {
        if (textView.text != defaultMessage) {
            // use hashtagBolder extension to bold the hashtags
            let hashtagBolder = HashtagBolder()
            let attributedText = hashtagBolder.boldHashtags(textView.text)
            
            // set textView (messageBox) text to new attributed text
            textView.attributedText = attributedText
        }
        if ((note.messagetext != textView.text || note.timestamp != datePicker.date) && textView.text != defaultMessage && !textView.text.isEmpty) {
            postButton.alpha = 1.0
        } else {
            postButton.alpha = 0.5
        }
    }
    
    // textViewDidBeginEditing, clear the messageBox if default message
    func textViewDidBeginEditing(textView: UITextView) {
        if (textView.text == defaultMessage) {
            textView.text = nil
        }
    }
    
    // textViewDidEndEditing, if empty set back to default message
    func textViewDidEndEditing(textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = defaultMessage
            textView.textColor = UIColor(red: 167/255, green: 167/255, blue: 167/255, alpha: 1)
        }
    }
}