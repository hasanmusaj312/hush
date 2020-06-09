//
//  PickerTextField.swift
//  Hush-SwiftUI
//
//  Created by Dima Virych on 08.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI

struct PickerTextField: UIViewRepresentable {
    
    var title: String
    var titles: [String]
    var picked: (String) -> Void
    var editabled: (Bool) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(titles: titles, picked: picked, textField: UITextField(), selectedTitle: "")
    }
    
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.inputView = context.coordinator.inputView
        field.inputAccessoryView = context.coordinator.toolBarView
        field.textAlignment = .right
        field.textColor = .white
        
        context.coordinator.textField = field
        
        return field
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        
        uiView.text = title
    }
}

extension PickerTextField {
    
    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        
        var textField: UITextField
        private var titles: [String]
        private var picked: (String) -> Void
        private var selectedTitle: String
        
        var inputView: UIPickerView {
            let picker = UIPickerView()
            picker.dataSource = self
            picker.delegate = self

            return picker
        }
        
        var toolBarView: UIToolbar {
            let toolbar = UIToolbar()
            toolbar.barStyle = UIBarStyle.default
            toolbar.isTranslucent = true
            toolbar.tintColor = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
            toolbar.sizeToFit()
            
            let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(self.donePicker))
            let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
            let cancelButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.cancelPicker))

            toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)
            toolbar.isUserInteractionEnabled = true
            
            return toolbar
        }
        
        @objc func donePicker() {
            picked(selectedTitle)
            textField.resignFirstResponder()
        }
        
        @objc func cancelPicker() {
            textField.resignFirstResponder()
        }
        
                
        init(titles: [String], picked: @escaping (String) -> Void, textField: UITextField, selectedTitle: String) {
            self.picked = picked
            self.titles = titles
            self.textField = textField
            self.selectedTitle = selectedTitle
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            
            1
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            
            titles.count
        }
        
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            
            titles[row]
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            
            selectedTitle = titles[row]
        }
    }
}

struct PickerTextField_Previews: PreviewProvider {
    
    @State static var str = "some"
    static var previews: some View {
        VStack {
            Text(str)
            PickerTextField(title: str, titles: ["1", "2", "3"], picked: { s in
                self.str = s
            }, editabled: { b in
                
            })
        }
    }
}


struct DateTextField: UIViewRepresentable {
    
    var title: String
    var picked: (Date) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(picked: picked, textField: UITextField(), selectedDate: Date())
    }
    
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.inputView = context.coordinator.inputView
        field.inputAccessoryView = context.coordinator.toolBarView
        field.textAlignment = .right
        field.textColor = .white
        field.resignFirstResponder()
        
        context.coordinator.textField = field
        
        return field
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        
        uiView.text = title
    }
    
}


extension DateTextField {
    
    class Coordinator: NSObject {
        var textField: UITextField
        private var picked: (Date) -> Void
        private var selectedDate: Date
        
        var inputView: UIDatePicker {
            let picker = UIDatePicker()
            picker.datePickerMode = .date
            picker.maximumDate = Date()
            picker.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)
            
            return picker
        }
        
        var toolBarView: UIToolbar {
            let toolbar = UIToolbar()
            toolbar.barStyle = UIBarStyle.default
            toolbar.isTranslucent = true
            toolbar.tintColor = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
            toolbar.sizeToFit()
            
            let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(self.donePicker))
            let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
            let cancelButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.cancelPicker))

            toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)
            toolbar.isUserInteractionEnabled = true
            
            return toolbar
        }
        
        @objc func donePicker() {
            picked(selectedDate)
            textField.resignFirstResponder()
        }
        
        @objc func cancelPicker() {
            textField.resignFirstResponder()
        }
        
        init(picked: @escaping (Date) -> Void, textField: UITextField, selectedDate: Date ) {
            self.picked = picked
            self.textField = textField
            self.selectedDate = selectedDate
        }
        
        @objc private func changed(_ picker: UIDatePicker) {
            selectedDate = picker.date
            //picked(picker.date)
        }
    }
}
