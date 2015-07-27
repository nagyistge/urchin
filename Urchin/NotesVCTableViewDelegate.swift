//
//  NotesVCTableViewDelegate.swift
//  urchin
//
//  Created by Ethan Look on 7/27/15.
//  Copyright (c) 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

extension NotesViewController: UITableViewDelegate {
    
    // heightForRowAtIndexPath
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (tableView.isEqual(notesTable)) {
            // NotesTable
            
            // Create labels that 'determine' height of cell
            
            // Configure the date label size first using extended dateFormatter
            // used for sizing usernameLabel
            let timedateLabel = UILabel()
            let dateFormatter = NSDateFormatter()
            timedateLabel.attributedText = dateFormatter.attributedStringFromDate(filteredNotes[indexPath.row].timestamp)
            timedateLabel.sizeToFit()
            
            // Configure the username label, with the full name
            let usernameLabel = UILabel()
            let usernameWidth = self.view.frame.width - (2 * noteCellInset + timedateLabel.frame.width + 2 * labelSpacing)
            usernameLabel.frame.size = CGSize(width: usernameWidth, height: CGFloat.max)
            usernameLabel.text = filteredNotes[indexPath.row].user!.fullName
            usernameLabel.font = UIFont(name: "OpenSans-Bold", size: 17.5)!
            usernameLabel.textColor = UIColor.blackColor()
            usernameLabel.adjustsFontSizeToFitWidth = false
            usernameLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
            usernameLabel.numberOfLines = 0
            usernameLabel.sizeToFit()
            
            let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width - 2*noteCellInset, height: CGFloat.max))
            let hashtagBolder = HashtagBolder()
            let attributedText = hashtagBolder.boldHashtags(filteredNotes[indexPath.row].messagetext)
            messageLabel.attributedText = attributedText
            messageLabel.adjustsFontSizeToFitWidth = false
            messageLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
            messageLabel.numberOfLines = 0
            messageLabel.sizeToFit()
            
            let cellHeight: CGFloat
            // if the user who created the note is the same as the current user, allow space for edit button
            if (filteredNotes[indexPath.row].user!.userid == user.userid) {
                cellHeight = noteCellInset + usernameLabel.frame.height + 2 * labelSpacing + messageLabel.frame.height + 2 * labelSpacing + 12.5 + noteCellInset
            } else {
                cellHeight = noteCellInset + usernameLabel.frame.height + 2 * labelSpacing + messageLabel.frame.height + noteCellInset
            }
            
            return cellHeight
        } else {
            // DropDownMenu
            
            if (indexPath.section == 0 && indexPath.row == 0) {
                // All / #nofilter
                
                let nameLabel = UILabel()
                nameLabel.text = "All"
                nameLabel.font = UIFont(name: "OpenSans-Bold", size: 17.5)
                nameLabel.sizeToFit()
                
                return userCellThickSeparator + userCellInset + nameLabel.frame.height + userCellInset + userCellThinSeparator
            } else if (indexPath.section == 1 && indexPath.row == 0) {
                // Logout
                
                let nameLabel = UILabel()
                nameLabel.text = "Logout"
                nameLabel.font = UIFont(name: "OpenSans-Bold", size: 17.5)
                nameLabel.sizeToFit()
                
                return userCellInset + nameLabel.frame.height + userCellInset + (userCellThickSeparator - userCellThinSeparator)
            } else {
                // Some group / team / filter
                
                let nameLabel = UILabel()
                nameLabel.frame.size = CGSize(width: self.view.frame.width - 2 * labelInset, height: 20.0)
                nameLabel.text = groups[indexPath.row - 1].fullName
                if (filter === groups[indexPath.row - 1]) {
                    nameLabel.font = UIFont(name: "OpenSans-Bold", size: 17.5)!
                } else {
                    nameLabel.font = UIFont(name: "OpenSans", size: 17.5)!
                }
                nameLabel.sizeToFit()
                
                return userCellInset + nameLabel.frame.height + userCellInset + userCellThinSeparator
            }
        }
    }

    // didSelectRowAtIndexPath
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // Immediately deselect the row
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if (tableView.isEqual(dropDownMenu)) {
            // dropDownMenu
            
            if (indexPath.section == 0) {
                // A group or all seleceted
                if (indexPath.row == 0) {
                    // 'All' / #nofilter selected
                    self.configureTitleView("All Notes")
                    self.filter = nil
                } else {
                    // Individual group / filter selected
                    let cell = dropDownMenu.cellForRowAtIndexPath(indexPath) as! UserDropDownCell
                    self.filter = cell.group
                    self.configureTitleView(filter.fullName!)
                }
                // filter the notes based upon new filter
                filterNotes()
                // Scroll notes to top
                self.notesTable.setContentOffset(CGPointMake(0, 0 - self.notesTable.contentInset.top), animated: true)
                // toggle the dropDownMenu (hides the dropDownMenu)
                self.dropDownMenuPressed()
            } else {
                // Logout selected
                // Unwind VC
                apiConnector.logout(self)
            }
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (scrollView.isEqual(notesTable)) {
            let height = scrollView.frame.height
            let contentYOffset = scrollView.contentOffset.y
            let distanceFromBottom = scrollView.contentSize.height - contentYOffset
            
            if (distanceFromBottom < height && !loadingNotes) {
                loadNotes()
            }
        }
    }
}