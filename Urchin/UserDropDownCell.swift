//
//  UserDropDownCell.swift
//  urchin
//
//  Created by Ethan Look on 6/19/15.
//  Copyright (c) 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

class UserDropDownCell: UITableViewCell {
    
    // UI elements
    let nameLabel: UILabel = UILabel()
    let rightView: UIImageView = UIImageView()
    let separator: UIView = UIView()
    let separatorTwo: UIView = UIView()

    // Group for the cell
    var group: User!
    
    func configure(key: String) {
        separator.removeFromSuperview()
        separatorTwo.removeFromSuperview()
        
        // Set background color to dark green
        self.backgroundColor = UIColor(red: 0/255, green: 54/255, blue: 62/255, alpha: 1)
        
        // Configure nameLabel
        nameLabel.textColor = UIColor(red: 253/255, green: 253/255, blue: 253/255, alpha: 1)
        nameLabel.frame.origin.x = userCellInset
        
        // Configure right image to a lovely right arrow
        rightView.image = rightArrow
        
        if (key == "all") {
            // Configure nameLabel to be 'All', or #nofilter
            nameLabel.text = allTeamsTitle
            nameLabel.font = mediumBoldFont
            nameLabel.sizeToFit()
            nameLabel.frame.origin.y = userCellThickSeparator + userCellInset
            
            // configure thick separator at the top
            separator.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: userCellThickSeparator)
            separator.backgroundColor = whiteQuarterAlpha
            self.addSubview(separator)
            
            // configure thin separator at the bottom
            separatorTwo.frame = CGRect(x: 0, y: self.frame.height - userCellThinSeparator, width: self.frame.width, height: userCellThinSeparator)
            separatorTwo.backgroundColor = whiteQuarterAlpha
            self.addSubview(separatorTwo)
            
        } else if (key == "logout") {
            // Configure the name label to be 'Logout'... for logging out
            self.nameLabel.text = logoutTitle
            nameLabel.font = mediumBoldFont
            nameLabel.sizeToFit()
            nameLabel.frame.origin.y = userCellThickSeparator - userCellThinSeparator + userCellInset
            
            // Configure the thick separator at the top
            // take out the height of the thin separator because the cell above has a thin separator at the bottom
            separator.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: userCellThickSeparator - userCellThinSeparator)
            separator.backgroundColor = whiteQuarterAlpha
            self.addSubview(separator)
            
        } else if (key == "group") {
            
            // position the nameLabel
            self.nameLabel.frame.origin = CGPoint(x: 6*userCellInset, y: userCellInset)
            
            // configure the thin separator at the bottom of the cell
            separator.frame = CGRect(x: 0, y: self.frame.height - userCellThinSeparator, width: self.frame.width, height: userCellThinSeparator)
            separator.backgroundColor = whiteQuarterAlpha
            self.addSubview(separator)
            
        }
        
        let imageWidth = rightArrow.size.width
        let imageHeight = rightArrow.size.height
        let imageX = self.frame.width - (userCellInset + imageWidth)
        let imageY = nameLabel.frame.midY - imageHeight / 2
        rightView.frame = CGRectMake(imageX, imageY, imageWidth, imageHeight)
        
        self.addSubview(rightView)
        self.addSubview(nameLabel)
    }
    
    func configure(group: User, arrow: Bool, bold: Bool) {
        self.group = group
        
        // configure the name label with the group name
        nameLabel.frame.size = CGSize(width: contentView.frame.width + userCellInset, height: dropDownGroupLabelHeight)
        self.nameLabel.text = group.fullName
        if (bold) {
            nameLabel.font = mediumBoldFont
        } else {
            nameLabel.font = mediumRegularFont
        }
        nameLabel.sizeToFit()
        
        configure("group")
        
        // hide the right arrow if necessary
        if (!arrow) {
            self.rightView.hidden = true
            
            nameLabel.frame.origin.x = self.frame.width / 2 - nameLabel.frame.width / 2
        }
    }
}