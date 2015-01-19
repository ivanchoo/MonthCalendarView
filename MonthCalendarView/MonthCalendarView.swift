//
//  MonthCalendarView.swift
//  MonthCalendar
//
//  Created by Ivan Choo on 15/1/15.
//  Copyright (c) 2015 Ivan Choo. All rights reserved.
//

import UIKit

public let MonthCalendarViewBackgroundKind = "MonthCalendarViewBackgroundKind"

private let MonthCalendarViewCurrentMonthSection = 2
private let MonthCalendarFlagYYYYMM: NSCalendarUnit = .EraCalendarUnit | .YearCalendarUnit | .MonthCalendarUnit
private let MonthCalendarFlagYYYYMMDD: NSCalendarUnit = MonthCalendarFlagYYYYMM | .DayCalendarUnit

// MARK: - MonthCalendarViewDelegate
@objc public protocol MonthCalendarViewDelegate {
    
    optional func calendarViewWillChangeCurrentMonth(calendarView: MonthCalendarView)
    optional func calendarViewDidChangeCurrentMonth(calendarView: MonthCalendarView)
    optional func calendarViewDidChangeIntrinsicContentSize(calendarView: MonthCalendarView)
    
    optional func calendarView(calendarView: MonthCalendarView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool
    optional func calendarView(calendarView: MonthCalendarView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    optional func calendarView(calendarView: MonthCalendarView, shouldDeselectItemAtIndexPath indexPath: NSIndexPath) -> Bool
    optional func calendarView(calendarView: MonthCalendarView, didDeselectItemAtIndexPath indexPath: NSIndexPath)
    
    optional func calendarView(calendarView: MonthCalendarView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool
    optional func calendarView(calendarView: MonthCalendarView, didHighlightItemAtIndexPath indexPath: NSIndexPath)
    optional func calendarView(calendarView: MonthCalendarView, didUnhighlightItemAtIndexPath indexPath: NSIndexPath)
    
    optional func calendarView(calendarView: MonthCalendarView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath)
    optional func calendarView(calendarView: MonthCalendarView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, forItemAtIndexPath indexPath: NSIndexPath)
    optional func calendarView(calendarView: MonthCalendarView, didEndDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath)
    optional func calendarView(calendarView: MonthCalendarView, didEndDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, forItemAtIndexPath indexPath: NSIndexPath)
    
    optional func calendarView(calendarView: MonthCalendarView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell?
    optional func calendarView(calendarView: MonthCalendarView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView?
    
}

// MARK: - MonthCalendarView

@IBDesignable public class MonthCalendarView: UIView, UIScrollViewDelegate,
    UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    public var calendar: NSCalendar = NSCalendar.currentCalendar() {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    public var currentMonth: NSDate = NSDate() {
        didSet {
            currentMonth = normalizeDate(currentMonth, withFlags: MonthCalendarFlagYYYYMM)
            setCalendarNeedsUpdate()
        }
    }
    
    public var previousMonth: NSDate {
        return dateFromCurrentMonthWithOffset(-1)
    }
    
    public var nextMonth: NSDate {
        return dateFromCurrentMonthWithOffset(1)
    }
    
    public var today: NSDate = NSDate() {
        didSet {
            today = normalizeDate(today, withFlags: MonthCalendarFlagYYYYMMDD)
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var calendarRowHeight: CGFloat = 60 {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var showHorizontalGridlines: Bool = true {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var showVerticalGridlines: Bool = true {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var showWeekendBackground: Bool = true {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var gridlineColor: UIColor = UIColor(white: 0.9, alpha: 1) {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var weekendBackgroundColor: UIColor = UIColor(white: 0.95, alpha: 1) {
        didSet {
            setCalendarNeedsUpdate()
        }
    }
    
    @IBInspectable public var allowsSelection: Bool {
        get {
            return collectionView.allowsSelection
        }
        set {
            collectionView.allowsSelection = newValue
        }
    }
    
    @IBInspectable public var allowsMultipleSelection: Bool {
        get {
            return collectionView.allowsMultipleSelection
        }
        set {
            collectionView.allowsMultipleSelection = newValue
        }
    }
    
    public weak var delegate: MonthCalendarViewDelegate?
    public var collectionView: UICollectionView!
    public var panGesture: UIPanGestureRecognizer!
    public private(set) var calendarCellSize = CGSizeZero
    public var selectedDates: [NSDate] {
        get {
            return selectedDatesSet.allObjects as [NSDate]
        }
        set {
            selectedDatesSet.removeAllObjects()
            selectedDatesSet.addObjectsFromArray(newValue)
            setCalendarNeedsUpdate()
        }
    }
    
    private var calendarNeedsUpdate: Bool = true
    private var sections: [MonthCalendarSection] = []
    private var lastPanOrigin = CGPointZero
    private var lastIntrisicContentSize = CGSizeZero
    private var selectedDatesSet = NSMutableSet()
    
    public func dateAtIndexPath(indexPath: NSIndexPath) -> NSDate? {
        if indexPath.section < 0 && indexPath.section >= sections.count {
            return nil
        }
        let section = sections[indexPath.section]
        if indexPath.item == 0 {
            return section.startDate
        }
        let comps = calendar.components(MonthCalendarFlagYYYYMMDD, fromDate: section.startDate)
        comps.day += indexPath.item
        return calendar.dateFromComponents(comps)!
    }
    
    public func indexPathForDate(date: NSDate) -> NSIndexPath? {
        let month = normalizeDate(date, withFlags: MonthCalendarFlagYYYYMM)
        for (index, section) in enumerate(sections) {
            if month == section.month {
                let comps = calendar.components(.DayCalendarUnit, fromDate: section.startDate, toDate: date, options: nil)
                return NSIndexPath(forItem: comps.day, inSection: index)
            }
        }
        return nil
    }
    
    public func dateFromCurrentMonthWithOffset(offset: Int) -> NSDate {
        let comps = calendar.components(MonthCalendarFlagYYYYMM, fromDate: currentMonth)
        comps.month += offset
        return calendar.dateFromComponents(comps)!
    }
    
    public func isWeekendForDate(date: NSDate) -> Bool {
        let comps = calendar.components(.WeekdayCalendarUnit, fromDate: date)
        return comps.weekday == 1 || comps.weekday == 7
    }

    public func isCurrentMonthForDate(date: NSDate) -> Bool {
        let normalized = normalizeDate(date, withFlags: MonthCalendarFlagYYYYMM)
        return normalized == currentMonth
    }
    
    public func isTodayEqualToDate(date: NSDate) -> Bool {
        let normalized = normalizeDate(date, withFlags: MonthCalendarFlagYYYYMMDD)
        return today == normalized
    }
    
    public func isSelectedDate(date: NSDate) -> Bool {
        let normalized = normalizeDate(date, withFlags: MonthCalendarFlagYYYYMMDD)
        return selectedDatesSet.containsObject(normalized)
    }
    
    public func setCurrentMonth(month: NSDate, animated: Bool) {
        if !animated {
            self.currentMonth = month
            return
        }
        let currentMonth = normalizeDate(month, withFlags: MonthCalendarFlagYYYYMM)
        var existingSection = -1
        for (index, section) in enumerate(sections) {
            if section.month == currentMonth {
                existingSection = index
                break
            }
        }
        if existingSection >= 0 {
            scrollCalendarToSection(existingSection, animated: true)
            return
        }
        // Rebuild datasource
        var months: [NSDate] = sections.map { return $0.month }
        let nextSection = currentMonth.earlierDate(currentMonth) == currentMonth ? 0 : months.count - 1
        months[nextSection] = currentMonth
        updateSectionsWithDates(months)
        collectionView.reloadData()
        updateCalendarSelection()
        collectionView.layoutIfNeeded()
        scrollCalendarToSection(nextSection, animated: true)
    }
    
    public func reloadItemsAtDates(dates: [NSDate]) {
        var indexPaths: [NSIndexPath] = []
        for date in dates {
            if let indexPath = indexPathForDate(date) {
                indexPaths.append(indexPath)
            }
        }
        if indexPaths.count > 0 {
            collectionView.reloadItemsAtIndexPaths(indexPaths)
        }
    }
    
    public func handlePan(gesture: UIPanGestureRecognizer) {
        let offset = gesture.translationInView(self)
        switch gesture.state {
        case .Began:
            lastPanOrigin = originForSection(MonthCalendarViewCurrentMonthSection)
            delegate?.calendarViewWillChangeCurrentMonth?(self)
            fallthrough
        case .Changed:
            collectionView.contentOffset = CGPoint(x: 0, y: lastPanOrigin.y - offset.y)
        case .Ended, .Cancelled:
            let velocity = gesture.velocityInView(self)
            let pushFactor = calendarRowHeight * 4 * 0.3
            var section = MonthCalendarViewCurrentMonthSection
            let diff = collectionView.contentOffset.y - lastPanOrigin.y
            if abs(velocity.y) > pushFactor || abs(diff) > pushFactor {
                section += (diff > 0 ? 1 : -1)
            }
            scrollCalendarToSection(section, animated: true)
        default:
            break
        }
    }
    
    public func updateCalendarIfNeeded() {
        if calendarNeedsUpdate {
            calendarNeedsUpdate = false
            updateCalendarCellSize()
            updateCalendarDataSource()
            collectionView.reloadData()
            scrollCalendarToSection(MonthCalendarViewCurrentMonthSection, animated: false)
            updateCalendarSelection()
            collectionView.layoutIfNeeded()
            invalidateIntrinsicContentSize()
        }
    }
    
    public func setCalendarNeedsUpdate() {
        calendarNeedsUpdate = true
        setNeedsLayout()
    }
    
    private func setup() {
        clipsToBounds = true
        let now = NSDate()
        currentMonth = now
        today = now
        collectionView = UICollectionView(frame: bounds, collectionViewLayout: MonthCalendarViewLayout())
        collectionView.backgroundColor = nil
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.scrollEnabled = false
        collectionView.registerClass(MonthCalendarViewCell.self, forCellWithReuseIdentifier: MonthCalendarViewCell.identifier())
        collectionView.registerClass(MonthCalendarViewBackground.self, forSupplementaryViewOfKind: MonthCalendarViewBackgroundKind,
            withReuseIdentifier: MonthCalendarViewBackground.identifier())
        addSubview(collectionView)
        panGesture = UIPanGestureRecognizer(target: self, action: "handlePan:")
        addGestureRecognizer(panGesture)
    }
    
    private func originForSection(section: Int) -> CGPoint {
        return collectionView.layoutAttributesForItemAtIndexPath(NSIndexPath(forItem: 0, inSection: section))!.frame.origin
    }
    
    private func scrollCalendarToSection(section: Int, animated: Bool) {
        collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: 0, inSection: section), atScrollPosition: .Top, animated: animated)
    }
    
    private func normalizeDate(date: NSDate, withFlags unitFlags: NSCalendarUnit) -> NSDate {
        let comps = calendar.components(unitFlags, fromDate: date)
        return calendar.dateFromComponents(comps)!
    }
    
    private func updateCalendarSelection() {
        for date in selectedDatesSet {
            if let indexPath = indexPathForDate(date as NSDate) {
                collectionView.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .None)
            }
        }
    }
    
    private func updateCalendarDataSource() {
        let calendar = self.calendar
        let comps = calendar.components(MonthCalendarFlagYYYYMM, fromDate: currentMonth)
        let month = comps.month
        let dates = Array(-2...2).map { (offset) -> NSDate in
            comps.month = month + offset
            return self.calendar.dateFromComponents(comps)!
        }
        updateSectionsWithDates(dates)
    }
    
    private func updateSectionsWithDates(dates: [NSDate]) {
        // TODO: update with [date, date, date ... ]
        let currentSections = sections.reduce([:], combine: { (var dict, section) -> [NSDate: MonthCalendarSection] in
            dict[section.month] = section
            return dict
        })
        let calendar = self.calendar
        let lastIndex = dates.count - 1
        sections = []
        for (index, month) in enumerate(dates) {
            if let exist = currentSections[month] {
                if index != lastIndex {
                    sections.append(exist)
                    continue
                }
            }
            // calculate the startDate of section, which is the first day of the first week of the current month
            var fdom: NSDate? // First day of month
            calendar.rangeOfUnit(.DayCalendarUnit, startDate: &fdom, interval: nil, forDate: month)
            var comps = calendar.components(MonthCalendarFlagYYYYMMDD | .WeekdayCalendarUnit, fromDate: fdom!)
            comps.day -= comps.weekday - 1
            let startDate = calendar.dateFromComponents(comps)!
            // determine the number of rows (weeks)
            // note that the last week of the month contains dates from next month, so we will exclude it (only if it's not the last section)
            comps.day = calendar.rangeOfUnit(.DayCalendarUnit, inUnit: .MonthCalendarUnit, forDate: month).length
            let ldom = calendar.dateFromComponents(comps)! // Last day of month
            let lwdom = calendar.components(.WeekdayCalendarUnit, fromDate: ldom).weekday // Last weekday of the month, 1 ~ 7
            let numberOfWeeks = calendar.rangeOfUnit(.WeekCalendarUnit, inUnit: .MonthCalendarUnit, forDate: month).length // Number of weeks in the month
            let numberOfRows = numberOfWeeks - (lwdom < 7 && index != lastIndex ? 1 : 0)
            let numberOfItems = numberOfRows * 7
            let section = MonthCalendarSection(month: month, startDate: startDate,
                numberOfRows: numberOfRows, numberOfWeeks: numberOfWeeks, numberOfItems: numberOfItems)
            sections.append(section)
        }
    }
    
    private func updateCalendarCellSize() {
        calendarCellSize = CGSize(width: CGRectGetWidth(bounds) / 7, height: calendarRowHeight)
    }

    private func updateCalendarScrollPosition() {
        let origin = collectionView.contentOffset
        var index = -1
        Array(0..<sections.count).reduce(CGFloat.max, combine: { (prev, section) -> CGFloat in
            let diff = abs(self.originForSection(section).y - origin.y)
            if diff < prev {
                index = section
                return diff
            }
            return prev
        })
        if index == MonthCalendarViewCurrentMonthSection {
            return
        }
        let section = sections[index]
        currentMonth = section.month
        delegate?.calendarViewDidChangeCurrentMonth?(self)
    }
    
    // MARK: UIView
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public override func layoutSubviews() {
        collectionView.frame = CGRect(x: 0, y: 0, width: CGRectGetWidth(bounds), height: calendarRowHeight * 6)
        updateCalendarIfNeeded()
        super.layoutSubviews()
        scrollCalendarToSection(MonthCalendarViewCurrentMonthSection, animated: false)
    }
    
    public override func intrinsicContentSize() -> CGSize {
        var height: CGFloat = UIViewNoIntrinsicMetric
        if !sections.isEmpty {
            height = calendarRowHeight * CGFloat(sections[MonthCalendarViewCurrentMonthSection].numberOfWeeks)
        }
        return CGSize(width: UIViewNoIntrinsicMetric, height: height)
    }
    
    public override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        let next = intrinsicContentSize()
        if !CGSizeEqualToSize(next, lastIntrisicContentSize) {
            lastIntrisicContentSize = next
            delegate?.calendarViewDidChangeIntrinsicContentSize?(self)
        }
    }
    
    // MARK: UICollectionViewDelegate
    
    public func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return delegate?.calendarView?(self, shouldSelectItemAtIndexPath: indexPath) ?? allowsSelection
    }
    
    public func collectionView(collectionView: UICollectionView, shouldDeselectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return delegate?.calendarView?(self, shouldDeselectItemAtIndexPath: indexPath) ?? allowsSelection
    }
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, didSelectItemAtIndexPath: indexPath)
        if !allowsMultipleSelection {
            selectedDatesSet.removeAllObjects()
        }
        let date = dateAtIndexPath(indexPath)
        assert(date != nil, "Inconsistent internal state, cannot resolve selection to date")
        selectedDatesSet.addObject(date!)
        if let cell = collectionView.cellForItemAtIndexPath(indexPath) {
           cell.setNeedsLayout()
        }
    }
    
    public func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, didDeselectItemAtIndexPath: indexPath)
        let date = dateAtIndexPath(indexPath)
        assert(date != nil, "Inconsistent internal state, cannot resolve deselection to date")
        selectedDatesSet.removeObject(date!)
        if let cell = collectionView.cellForItemAtIndexPath(indexPath) {
            cell.setNeedsLayout()
        }
    }
    
    public func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, willDisplayCell: cell, forItemAtIndexPath: indexPath)
    }
    
    public func collectionView(collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, atIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, willDisplaySupplementaryView: view, forElementKind: elementKind, forItemAtIndexPath: indexPath)
    }
    
    public func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, didEndDisplayCell: cell, forItemAtIndexPath: indexPath)
    }
    
    public func collectionView(collectionView: UICollectionView, didEndDisplayingSupplementaryView view: UICollectionReusableView, forElementOfKind elementKind: String, atIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, didEndDisplaySupplementaryView: view, forElementKind: elementKind, forItemAtIndexPath: indexPath)
    }
    
    public func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return delegate?.calendarView?(self, shouldHighlightItemAtIndexPath: indexPath) ?? true
    }
    
    public func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, didHighlightItemAtIndexPath: indexPath)
    }
    
    public func collectionView(collectionView: UICollectionView, didUnhighlightItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.calendarView?(self, didUnhighlightItemAtIndexPath: indexPath)
    }
    
    // MARK: UICollectionViewDataSource
    
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].numberOfItems
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        if let cell = delegate?.calendarView?(self, cellForItemAtIndexPath: indexPath) {
            return cell
        }
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(MonthCalendarViewCell.identifier(), forIndexPath: indexPath) as MonthCalendarViewCell
        cell.calendarView = self
        cell.selected = contains(collectionView.indexPathsForSelectedItems() as [NSIndexPath], indexPath)
        return cell
    }
    
    public func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if let view = delegate?.calendarView?(self, viewForSupplementaryElementOfKind: kind, atIndexPath: indexPath) {
            return view
        }
        if kind == MonthCalendarViewBackgroundKind {
            let view = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: MonthCalendarViewBackground.identifier(), forIndexPath: indexPath) as MonthCalendarViewBackground
            view.calendarView = self
            return view
        }
        assertionFailure("Unknown supplementary element kind \(kind)")
    }
    
    // MARK: UICollectionViewDelegateFlowLayout
    
    public func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    public func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    public func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return calendarCellSize
    }
    
    // MARK: UIScrollViewDelegate

    public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        updateCalendarScrollPosition()
    }
}

// MARK: - MonthCalendarViewLayout

public class MonthCalendarViewLayout: UICollectionViewFlowLayout {
    
    public override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? { 
        if var attrs = super.layoutAttributesForElementsInRect(rect) {
            attrs.append(layoutAttributesForSupplementaryViewOfKind(MonthCalendarViewBackgroundKind, atIndexPath: NSIndexPath(forItem: 0, inSection: 0)))
            return attrs
        }
        return nil
    }
    
    public override func layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        var attr = super.layoutAttributesForSupplementaryViewOfKind(elementKind, atIndexPath: indexPath)
        switch elementKind {
        case MonthCalendarViewBackgroundKind:
            if attr == nil {
                attr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, withIndexPath: indexPath)
            }
            attr.zIndex = -1
            attr.frame = CGRect(origin: CGPointZero, size: collectionViewContentSize())
        default:
            break
        }
        return attr
    }
    
}

// MARK: - MonthCalendarViewCell

/// Default implementation of day cell
public class MonthCalendarViewCell: UICollectionViewCell {
    
    weak public var calendarView: MonthCalendarView? {
        didSet {
            setNeedsLayout()
        }
    }
    
    public let label = UILabel()
    public var indexPath: NSIndexPath?
    private var circleView: UIView?
    
    public class func identifier() -> String {
        return "MonthCalendarViewCell"
    }
    
    public override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes!) {
        super.applyLayoutAttributes(layoutAttributes)
        indexPath = layoutAttributes.indexPath
        setNeedsLayout()
    }
    
    public override func layoutSubviews() {
        // TODO: Fix selection flickering
        if label.superview == nil {
            label.textAlignment = .Center
            label.frame = bounds
            label.autoresizingMask = .FlexibleWidth | .FlexibleHeight
            contentView.addSubview(label)
        }
        let date: NSDate! = indexPath != nil ? calendarView?.dateAtIndexPath(indexPath!) : nil
        if date != nil {
            let cv = calendarView!
            let comps = cv.calendar.components(.DayCalendarUnit, fromDate: date)
            let isToday = cv.isTodayEqualToDate(date)
            let isCurrentMonth = cv.isCurrentMonthForDate(date)
            let fontSize: CGFloat = 17
            let isBold = isCurrentMonth && isToday
            let isSelected = cv.isSelectedDate(date)
            label.text = "\(comps.day)"
            label.font = isBold ? UIFont.boldSystemFontOfSize(fontSize) : UIFont.systemFontOfSize(fontSize)
            if isSelected {
                label.textColor = UIColor.whiteColor()
                if circleView == nil {
                    circleView = UIView()
                    contentView.insertSubview(circleView!, atIndex: 0)
                }
                let width = CGRectGetWidth(bounds)
                let height = CGRectGetHeight(bounds)
                let circleDiameter = min(fontSize + 12, min(width, height))
                let circleSize = CGSize(width: circleDiameter, height: circleDiameter)
                if isCurrentMonth {
                    circleView!.backgroundColor = isToday ? tintColor : UIColor.darkTextColor()
                } else {
                    circleView!.backgroundColor = UIColor.lightGrayColor()
                }
                circleView!.layer.cornerRadius = circleDiameter / 2
                circleView!.frame = CGRect(origin: CGPoint(x: (width - circleDiameter) / 2, y: (height - circleDiameter) / 2), size: circleSize)
            } else {
                label.textColor = isToday ? tintColor : (isCurrentMonth ? UIColor.darkTextColor() : UIColor.lightGrayColor())
                circleView?.removeFromSuperview()
                circleView = nil
            }
        } else {
            label.text = ""
            backgroundColor = nil
        }
        super.layoutSubviews()
    }
}

// MARK: - MonthCalendarViewBackground

public class MonthCalendarViewBackground: UICollectionReusableView {
    
    public weak var calendarView: MonthCalendarView? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public class func identifier() -> String {
        return "MonthCalendarViewBackground"
    }
    
    public override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes!) {
        super.applyLayoutAttributes(layoutAttributes)
        opaque = false
        setNeedsDisplay()
    }
    
    public override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        let ctx = UIGraphicsGetCurrentContext()
        CGContextClearRect(ctx, bounds)
        if let cv = self.calendarView {
            let width = CGRectGetWidth(bounds)
            let height = CGRectGetHeight(bounds)
            let cellSize = cv.calendarCellSize
            // Draw weekends, first and last column
            if cv.showWeekendBackground {
                let weekends = [
                    CGRect(x: 0, y: 0, width: cellSize.width, height: height),
                    CGRect(x: width - cellSize.width, y: 0, width: cellSize.width, height: height)
                ]
                CGContextSetFillColorWithColor(ctx, cv.weekendBackgroundColor.CGColor)
                for rect in weekends {
                    CGContextFillRect(ctx, rect)
                }
            }
            if cv.showHorizontalGridlines {
                var y = cellSize.height
                while y < height {
                    CGContextMoveToPoint(ctx, 0, y)
                    CGContextAddLineToPoint(ctx, width, y)
                    y += cellSize.height
                }
            }
            if cv.showVerticalGridlines {
                var x = cellSize.width
                var i = 0
                while x < width {
                    CGContextMoveToPoint(ctx, x, 0)
                    CGContextAddLineToPoint(ctx, x, height)
                    x += cellSize.width
                    i++
                }
            }
            CGContextSetLineWidth(ctx, 1.0 / UIScreen.mainScreen().scale)
            CGContextSetStrokeColorWithColor(ctx, cv.gridlineColor.CGColor)
            CGContextStrokePath(ctx)
        }
    }
}

// MARK: - MonthCalendarSection

/// Internal structure containing month section information
private struct MonthCalendarSection {
    let month: NSDate
    let startDate: NSDate
    let numberOfRows: Int
    let numberOfWeeks: Int
    let numberOfItems: Int
}