//
//  ViewController.swift
//  MonthCalendar
//
//  Created by Ivan Choo on 15/1/15.
//  Copyright (c) 2015 Ivan Choo. All rights reserved.
//

import UIKit
import MonthCalendarView

class ViewController: UIViewController, MonthCalendarViewDelegate {

    var dateFormatter: NSDateFormatter!
    var animateDateChange: Bool = true
    
    @IBOutlet weak var calendarView: MonthCalendarView!
    
    @IBAction func goto(sender: UISegmentedControl) {
        let next = sender.selectedSegmentIndex == 0  ? calendarView.nextMonth : calendarView.previousMonth
        gotoDate(next)
    }
    
    func gotoDate(date: NSDate) {
        calendarView.setCurrentMonth(date, animated: animateDateChange)
        if !animateDateChange {
            updateNavigationTitle()
        }
    }
    
    @IBAction func gotoToday(sender: AnyObject) {
        gotoDate(NSDate())
    }
    
    func showHorizontalGridlines(sender: UISwitch) {
        calendarView.showHorizontalGridlines = sender.on
    }
    
    func showVerticalGridlines(sender: UISwitch) {
        calendarView.showVerticalGridlines = sender.on
    }
    
    func showWeekendBackground(sender: UISwitch) {
        calendarView.showWeekendBackground = sender.on
    }
    
    func showScrollAnimation(sender: UISwitch) {
        self.animateDateChange = sender.on
    }
    
    func setSelectionMode(sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            calendarView.allowsSelection = true
            calendarView.allowsMultipleSelection = false
        case 2:
            calendarView.allowsSelection = true
            calendarView.allowsMultipleSelection = true
        default:
            calendarView.allowsSelection = false
            calendarView.allowsMultipleSelection = false
        }
    }
    
    func updateNavigationTitle() {
        navigationItem.title = dateFormatter.stringFromDate(calendarView.currentMonth)
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MMMM, YYYY"
        dateFormatter.timeZone = calendarView.calendar.timeZone
        calendarView.delegate = self
        calendarView.calendarRowHeight = CGRectGetWidth(view.bounds) / 7
        updateNavigationTitle()
    }
    
    // MARK: - MonthCalendarViewDelegate
    
    func calendarViewDidChangeCurrentMonth(calendarView: MonthCalendarView) {
        updateNavigationTitle()
    }
    
    func calendarViewDidChangeIntrinsicContentSize(calendarView: MonthCalendarView) {
        UIView.animateWithDuration(0.3, delay: 0, options: .AllowUserInteraction | .BeginFromCurrentState, animations: { _ in
            self.view.setNeedsUpdateConstraints()
            self.view.layoutIfNeeded()
            }) { _ in
                
        }
    }

}
