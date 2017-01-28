//
//  iTunesHelper.swift
//  Muse
//
//  Created by Marco Albera on 28/01/17.
//  Copyright © 2017 Edge Apps. All rights reserved.
//

import ScriptingBridge

@objc fileprivate protocol iTunesApplication {
    @objc optional var currentTrack: iTunesTrack { get }
    @objc optional var playerPosition: Double { get }
    @objc optional var playerState: iTunesEPlS { get }
    @objc optional var soundVolume: Int { get }
    @objc optional var songRepeat: iTunesERpt { get }
    @objc optional var shuffleEnabled: Bool { get }
    
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func previousTrack()
    
    @objc optional func setPlayerPosition(_ position: Double)
    @objc optional func setSoundVolume(_ volume: Int)
    @objc optional func setSongRepeat(_ songRepeat: iTunesERpt)
    @objc optional func setShuffleEnabled(_ shuffleEnabled: Bool)
}

@objc fileprivate protocol iTunesTrack {
    @objc optional var name: String { get }
    @objc optional var artist: String { get }
    @objc optional var album: String { get }
    @objc optional var duration: Double { get }
    @objc optional var artworks: [iTunesArtwork] { get }
}

@objc fileprivate protocol iTunesArtwork {
    @objc optional var data: NSImage { get }
    @objc optional var description: String { get }
}

extension SBObject: iTunesArtwork { }

extension SBApplication: iTunesApplication { }

class iTunesHelper: PlayerHelper {
    
    // SIngleton constructor
    static let shared = iTunesHelper()
    
    // The SBApplication object bound to the helper class
    private let application: iTunesApplication? = SBApplication.init(bundleIdentifier: BundleIdentifier)
    
    // MARK: Player features
    
    let doesSendPlayPauseNotification = true
    
    // MARK: Song data
    
    var song: Song {
        guard let application = application else { return Song() }
        
        guard let currentTrack = application.currentTrack else { return Song() }
        
        return Song(name: currentTrack.name!,
                    artist: currentTrack.artist!,
                    album: currentTrack.album!,
                    duration: trackDuration)
    }
    
    // MARK: Playback controls
    
    func togglePlayPause() {
        guard let application = application else { return }
        
        application.playpause!()
        
        execPlayPauseHandler()
    }
    
    func nextTrack() {
        guard let application = application else { return }
        
        application.nextTrack!()
        
        trackChangedHandler(true)
    }
    
    func previousTrack() {
        guard let application = application else { return }
        
        application.previousTrack!()
        
        trackChangedHandler(false)
    }
    
    // MARK: Playback status
    
    var playerState: PlayerState {
        guard let application = application else { return .stopped }
        
        // Return current playback status ( R/O )
        if application.playerState == iTunesEPlSPlaying {
            return .playing
        } else if application.playerState == iTunesEPlSPaused {
            return .paused
        } else if application.playerState == iTunesEPlSStopped {
            return .stopped
        }
        
        // By default return stopped status
        return .stopped
    }
    
    var playbackPosition: Double {
        set {
            guard let application = application else { return }
            
            // Set the position on the player
            application.setPlayerPosition!(newValue)
        }
        
        get {
            guard let application = application else { return 0 }
            
            guard let playbackPosition = application.playerPosition else { return 0 }
            
            // Return current playback position
            return playbackPosition
        }
    }
    
    var trackDuration: Double {
        guard let application = application else { return 0 }
        
        guard   let currentTrack = application.currentTrack,
                let trackDuration = currentTrack.duration
        else { return 0 }
        
        // Return current track duration
        return trackDuration
    }
    
    func scrub(to doubleValue: Double?, touching: Bool) {
        if !touching, let value = doubleValue {
            playbackPosition = value * trackDuration
        }
        
        timeChangedHandler(touching, doubleValue)
    }
    
    // MARK: Playback options
    
    var volume: Int {
        set {
            guard let application = application else { return }
            
            // Set the volume on the player
            application.setSoundVolume!(newValue)
        }
        
        get {
            guard let application = application else { return 0 }
            
            guard let volume = application.soundVolume else { return 0 }
            
            // Get current volume
            return volume
        }
    }
    
    var repeating: Bool {
        set {
            guard let application = application else { return }
            
            let repeating: iTunesERpt = newValue ? iTunesERptAll : iTunesERptOff
            
            // Toggle repeating on the player
            application.setSongRepeat!(repeating)
            
            // Call the handler with new repeat value
            execShuffleRepeatChangedHandler(repeatChanged: true)
        }
        
        get {
            guard let application = application else { return false }
            
            guard let repeating = application.songRepeat else { return false }
            
            // Return current repeating status
            return repeating == iTunesERptOne || repeating == iTunesERptAll
        }
    }
    
    var shuffling: Bool {
        set {
            guard let application = application else { return }
            
            // Toggle shuffling on the player
            application.setShuffleEnabled!(newValue)
            
            // Call the handler with new shuffle value
            execShuffleRepeatChangedHandler(shuffleChanged: true)
        }
        
        get {
            guard let application = application else { return false }
            
            guard let shuffling = application.shuffleEnabled else { return false }
            
            // Return current shuffling status
            return shuffling
        }
    }
    
    // MARK: Artwork
    
    func artwork() -> Any? {
        guard let application = application else { return nil }
        
        // Returns the first available artwork
        return application.currentTrack?.artworks?[0].data
    }
    
    // MARK: Callbacks
    
    var playPauseHandler: () -> () = { }
    
    var trackChangedHandler: (Bool) -> () = { _ in }
    
    var timeChangedHandler: (Bool, Double?) -> () = { _, _ in }
    
    var shuffleRepeatChangedHandler: (Bool, Bool) -> () = { _, _ in }
    
    // MARK: Application identifier
    
    static let BundleIdentifier = "com.apple.iTunes"
    
    // MARK: Notification ID
    
    static let rawTrackChangedNotification = BundleIdentifier + ".playerInfo"
    
}