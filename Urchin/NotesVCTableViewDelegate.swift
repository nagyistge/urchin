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
            
            let note = filteredNotes[indexPath.row]
            
            // Create labels that 'determine' height of cell
            
            // Configure the username label, with the full name
            let usernameLabel = UILabel()
            
            var usernameWidth = self.view.frame.width - (2 * noteCellInset)
            if (note.user!.userid == user.userid) {
                // Compensate for width of edit button
                usernameWidth -= editButtonWidth
            }
            usernameLabel.frame.size = CGSize(width: usernameWidth, height: CGFloat.max)
            var attrUsernameLabel = NSMutableAttributedString(string: note.user!.fullName!, attributes: [NSForegroundColorAttributeName: noteTextColor, NSFontAttributeName: mediumSemiboldFont])
            if (note.groupid != note.userid) {
                for group in groups {
                    if (group.userid == note.groupid) {
                        attrUsernameLabel = NSMutableAttributedString(string: "\(note.user!.fullName!) to \(group.fullName!)", attributes: [NSForegroundColorAttributeName: noteTextColor, NSFontAttributeName: mediumSemiboldFont])
                        break
                    }
                }
            }
            usernameLabel.attributedText = attrUsernameLabel
            usernameLabel.adjustsFontSizeToFitWidth = false
            usernameLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
            usernameLabel.numberOfLines = 0
            usernameLabel.sizeToFit()
            
            // Configure the date label size using extended dateFormatter
            let timedateLabel = UILabel()
            let dateFormatter = NSDateFormatter()
            timedateLabel.attributedText = dateFormatter.attributedStringFromDate(note.timestamp)
            timedateLabel.sizeToFit()
            
            let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width - 2*noteCellInset, height: CGFloat.max))
            let hashtagBolder = HashtagBolder()
            let attributedText = hashtagBolder.boldHashtags(note.messagetext)
            messageLabel.attributedText = attributedText
            messageLabel.adjustsFontSizeToFitWidth = false
            messageLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
            messageLabel.numberOfLines = 0
            messageLabel.sizeToFit()
            
            // Calculate the total note cell height
            var cellHeight: CGFloat = noteCellInset + usernameLabel.frame.height + labelSpacing / 2 + timedateLabel.frame.height + 2 * labelSpacing + messageLabel.frame.height + noteCellInset
            
            return cellHeight
            
            
        } else {
            // DropDownMenu
            
            if (groups.count == 1) {
                
                if (indexPath.section == 0 && indexPath.row == 0) {
                    // Logout
                    
                    let nameLabel = UILabel()
                    nameLabel.text = logoutTitle
                    nameLabel.font = mediumBoldFont
                    nameLabel.sizeToFit()
                    
                    return userCellInset + nameLabel.frame.height + userCellInset + (userCellThickSeparator - userCellThinSeparator)
                } else if (indexPath.section == 1 && indexPath.row == 0) {
                    
                    // Version
                    
                    let nameLabel = UILabel()
                    nameLabel.text = UIApplication.versionBuildServer()
                    nameLabel.font = mediumBoldFont
                    nameLabel.sizeToFit()
                    
                    return userCellInset + nameLabel.frame.height + userCellInset + userCellThickSeparator
                    
                } else {
                    return 0
                }
                
            } else {
                
                if (indexPath.section == 0 && indexPath.row == 0) {
                    // All / #nofilter
                    
                    let nameLabel = UILabel()
                    nameLabel.text = allTeamsTitle
                    nameLabel.font = mediumBoldFont
                    nameLabel.sizeToFit()
                    
                    return userCellThickSeparator + userCellInset + nameLabel.frame.height + userCellInset + userCellThinSeparator
                } else if (indexPath.section == 1 && indexPath.row == 0) {
                    // Logout
                    
                    let nameLabel = UILabel()
                    nameLabel.text = logoutTitle
                    nameLabel.font = mediumBoldFont
                    nameLabel.sizeToFit()
                    
                    return userCellInset + nameLabel.frame.height + userCellInset + (userCellThickSeparator - userCellThinSeparator)
                } else if (indexPath.section == 2 && indexPath.row == 0) {
                    
                    // Version
                    
                    let nameLabel = UILabel()
                    nameLabel.text = UIApplication.versionBuildServer()
                    nameLabel.font = mediumBoldFont
                    nameLabel.sizeToFit()
                    
                    return userCellInset + nameLabel.frame.height + userCellInset + userCellThickSeparator
                    
                } else {
                    // Some group / team / filter
                    
                    let nameLabel = UILabel()
                    nameLabel.frame.size = CGSize(width: self.view.frame.width - 2 * labelInset, height: dropDownGroupLabelHeight)
                    nameLabel.text = groups[indexPath.row - 1].fullName
                    if (filter === groups[indexPath.row - 1]) {
                        nameLabel.font = mediumBoldFont
                    } else {
                        nameLabel.font = mediumRegularFont
                    }
                    nameLabel.sizeToFit()
                    
                    return userCellInset + nameLabel.frame.height + userCellInset + userCellThinSeparator
                }
                
            }
        }
    }

    // didSelectRowAtIndexPath
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // Immediately deselect the row
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if (tableView.isEqual(dropDownMenu)) {
            // dropDownMenu
            
            if (groups.count == 1) {
                
                if (indexPath.section == 0) {
                    self.logout()
                }
                
            } else {
                
                if (indexPath.section == 0) {
                    // A group or all seleceted
                    if (indexPath.row == 0) {
                        if (filter != nil) {
                            self.apiConnector.trackMetric("Clicked All in Feed")
                        }
                        
                        // 'All' / #nofilter selected
                        self.configureTitleView(allNotesTitle)
                        self.filter = nil
                    } else {
                        
                        // Individual group / filter selected
                        if (filter !== groups[indexPath.row - 1]) {
                            self.apiConnector.trackMetric("Changed Person in Feed")
                        }
                        self.filter = groups[indexPath.row - 1]
                        self.configureTitleView(filter.fullName!)
                    }
                    // filter the notes based upon new filter
                    filterNotes()
                    // Scroll notes to top
                    self.notesTable.setContentOffset(CGPointMake(0, -self.notesTable.contentInset.top), animated: true)
                    // toggle the dropDownMenu (hides the dropDownMenu)
                    self.dropDownMenuPressed()
                } else if (indexPath.section == 1) {
                    self.logout()
                }
                
            }
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (scrollView.isEqual(notesTable)) {
            
            // Determine whether the notesTable is scrolled all the way down
            let height = scrollView.frame.height
            let contentYOffset = scrollView.contentOffset.y
            let distanceFromBottom = scrollView.contentSize.height - contentYOffset
            
            // If so, load notes
            if (distanceFromBottom == height && !loadingNotes) {
                self.apiConnector.trackMetric("Scrolled Down For More Notes")
                
                loadNotes()
            }
        }
    }
}