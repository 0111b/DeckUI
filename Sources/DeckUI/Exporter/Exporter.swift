//
//  Exporter.swift
//  DeckUI
//
//  Created by Alexandr Goncharov on 13.09.2022.
//

import Foundation

protocol Exporter {
    func export(deck: Deck) async throws
}
