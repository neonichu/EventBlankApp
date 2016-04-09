//
//  SessionCell.swift
//  EventBlank2-iOS
//
//  Created by Marin Todorov on 4/9/16.
//  Copyright © 2016 Underplot ltd. All rights reserved.
//

import UIKit
import RealmSwift

import RxSwift
import RxCocoa

import Then

class SessionCell: UITableViewCell, ClassIdentifier {
    
    private let bag = DisposeBag()
    private var reuseBag = DisposeBag()
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var trackLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var speakerLabel: UILabel!
    @IBOutlet weak var speakerImageView: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var btnToggleIsFavorite: UIButton!
    @IBOutlet weak var btnSpeakerIsFavorite: UIButton!

    // input
    let isFavorite = PublishSubject<Bool>()
    let isFavoriteSpeaker = PublishSubject<Bool>()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        btnToggleIsFavorite.setImage(UIImage(named: "like-full")?.imageWithRenderingMode(.AlwaysTemplate), forState: .Selected)
        
        btnSpeakerIsFavorite.setImage(UIImage(named: "like-full")?.imageWithRenderingMode(.AlwaysTemplate), forState: .Selected)
        btnSpeakerIsFavorite.setImage(nil, forState: .Normal)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        reuseBag = DisposeBag()
        speakerImageView.image = nil
    }

    static func cellOfTable(tv: UITableView, session: Session, event: EventData) -> SessionCell {
        return tv.dequeueReusableCell(SessionCell).then {cell in
            cell.populateFromSession(session, event: event)
        }
    }
    
    func populateFromSession(session: Session, event: EventData) {
        
        //setupUI
        titleLabel.text = session.title
        speakerLabel.text = session.speakers.first!.name
        trackLabel.text = session.track?.track ?? ""
        
        timeLabel.text = shortStyleDateFormatter.stringFromDate(session.beginTime!)
        
        let userImage = session.speakers.first!.photo ?? UIImage(named: "empty")!
        userImage.asyncToSize(.FillSize(speakerImageView.bounds.size), cornerRadius: speakerImageView.bounds.size.width/2, completion: {result in
            self.speakerImageView.image = result
        })
        
        locationLabel.text = session.location?.location
        
        //theme
        titleLabel.textColor = event.mainColor
        trackLabel.textColor = event.mainColor.lightenColor(0.1).desaturatedColor()
        speakerLabel.textColor = UIColor.blackColor()
        locationLabel.textColor = UIColor.blackColor()
        
        //check if in the past
        if let beginTime = session.beginTime where NSDate().isLaterThanDate(beginTime) {
            titleLabel.textColor = titleLabel.textColor.desaturateColor(0.5).lighterColor()
            trackLabel.textColor = titleLabel.textColor
            speakerLabel.textColor = UIColor.grayColor()
            locationLabel.textColor = UIColor.grayColor()
        }
        
        //bindUI
        isFavorite.bindTo(btnToggleIsFavorite.rx_selected).addDisposableTo(bag)
        isFavoriteSpeaker.bindTo(btnSpeakerIsFavorite.rx_selected).addDisposableTo(bag)

        btnToggleIsFavorite.rx_tap.subscribeNext {[unowned self] in
            self.isFavorite.onNext(!self.btnToggleIsFavorite.selected)
            self.btnToggleIsFavorite.animateSelect(scale: 0.8, completion: nil)
        }.addDisposableTo(reuseBag)
    }

}
