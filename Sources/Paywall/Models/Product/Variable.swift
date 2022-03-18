//
//  Variable.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Variable: Decodable, Equatable {
  var key: String
  var value: JSON
}
