//
//  SearchViewController.swift
//  StretchyTableViewHeader
//
//  Created by Ahmed, Yehya on 11/25/22.
//

import UIKit
import CoreData

/*
 Protocol for Delegate. DiaryTableViewController is the delegate used
 Save saves the entry to the diary list
 */
protocol SeachViewControllerDelegate: AnyObject {
    func save(_ foodEntry: DiaryEntry)
}

class SearchViewController: UIViewController {

    struct TableView {
      struct CellIdentifiers {
        static let searchResultCell = "SearchResultCell"
          static let nothingFoundCell = "NothingFoundCell"
      }
    }
    

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    
    var hasSearched = false
    var foodResult = FoodEntry(foods: [])
    var dataTask: URLSessionDataTask?
    weak var delegate: SeachViewControllerDelegate?
    var managedObjectContext: NSManagedObjectContext!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Sets the BookmarkIcon to a Barcode scanning icon
        searchBar.setImage(UIImage(systemName: "barcode.viewfinder"), for: .bookmark, state: .normal)
        
        // Register the NIB tablecell SearchResultCell
        var cellNib = UINib(nibName: TableView.CellIdentifiers.searchResultCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.searchResultCell)

        // register the nothing found cell
        cellNib = UINib(nibName:
        TableView.CellIdentifiers.nothingFoundCell, bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: TableView.CellIdentifiers.nothingFoundCell)
        
        // Space between results and searchBar
        tableView.contentInset = UIEdgeInsets(top: 51, left: 0, bottom: 0, right: 0)
        
        // Keyboard popup on launch
         searchBar.becomeFirstResponder()
    }
    
    /*
     Hide Navigation Bar for Diary screen
     */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    /*
     Bring back Navigation Bar once screen changes
     */
    override func viewWillDisappear(_ animated: Bool) {
     super.viewWillDisappear(animated)
     navigationController?.isNavigationBarHidden = false
     
    }
    
    // MARK: - Helper Methods
    
    /*
     Parse the results from /vs/natural/nutrients API to a FoodEntry
     */
    func parseJSON(data: Data) -> FoodEntry? {
        
        var returnValue: FoodEntry?
        
        do {
            returnValue = try JSONDecoder().decode(FoodEntry.self, from: data)
        } catch {
            print("Error took place\(error.localizedDescription).")
        }
        
        return returnValue
    }
    
    /*
     Delay in showing the animation and returning back to searchController
     */
    func afterDelay(_ seconds: Double, run: @escaping () -> Void) {
      DispatchQueue.main.asyncAfter(
        deadline: .now() + seconds,
        execute: run)
    }
    
    @IBAction func cancel(_ unwindSegue: UIStoryboardSegue) {
        print("CANCEL CLICKEDDDDDDD")
    }
    
    @IBAction func saveeeee(_ unwindeSegue: UIStoryboardSegue) {
        guard let mainView = navigationController?.parent?.view else { return }
        let hudView = HudView.hud(inView: mainView, animated: true)
        hudView.text = "Logged"
        
        if let entryDetailViewController = unwindeSegue.source as? EntryDetailViewController {
            let foodEntry = entryDetailViewController.foodEntryToAdd
            if let foodEntry = foodEntry {
               // delegate?.save(foodEntry)
                let entry = DiaryEntry(context: managedObjectContext)
                entry.food_name = foodEntry.food_name
                entry.nf_calories = foodEntry.nf_calories
                entry.nf_protein = foodEntry.nf_protein!
                entry.nf_total_carbohydrate = foodEntry.nf_total_carbohydrate!
                entry.nf_sugars = foodEntry.nf_sugars!
                entry.serving_qty = Int16(foodEntry.serving_qty)
                entry.serving_weight_grams = Int16(foodEntry.serving_weight_grams)
                entry.nf_total_fat = foodEntry.nf_total_fat!
                delegate?.save(entry)
                do {
                    try managedObjectContext.save()
                    afterDelay(0.6) {
                        hudView.hide()
                    }
                } catch {
                    fatalError("Error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "foodItem" {
            let controller = segue.destination as! EntryDetailViewController
            let indexPath = sender as! IndexPath
            let foodDetail = foodResult.foods[indexPath.row]
         //   controller.delegate = self
            controller.foodEntryToAdd = foodDetail
          //  controller.managedObjectContext = managedObjectContext
        }
    }
    

}

    func performAPI(searchText: String) -> NSMutableURLRequest {
        let headers = [
            "x-app-id": "6aed71f3",
            "x-app-key": "7a0d942304579d189e44f433f28c8c0d",
            "x-remote-user-id": "0"
        ]
        
        let body: [String: String] = ["query": searchText]
        let finalBody = try! JSONSerialization.data(withJSONObject: body)
        let request = NSMutableURLRequest(url: NSURL(string: "https://trackapi.nutritionix.com/v2/natural/nutrients")! as URL,
                                                cachePolicy: .useProtocolCachePolicy,
                                            timeoutInterval: 10.0)
        
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = finalBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

       return request
        
    }

extension SearchViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        if !searchBar.text!.isEmpty {
          searchBar.resignFirstResponder() // remove keyboard
            dataTask?.cancel()
            tableView.reloadData()
            hasSearched = true
            
            let request = performAPI(searchText: searchBar.text!)
            
            let session = URLSession.shared
            
            dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
                if let error = error  {
                    print(error.localizedDescription)
                    
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    
                    if let data = data, (String(data: data, encoding: .utf8) != nil) {
                        
                        let todoItem = self.parseJSON(data: data)
                        guard let todoItemModel = todoItem else { return }
                        
                        self.foodResult = todoItemModel
                        print(todoItemModel)
                        DispatchQueue.main.async {
                          self.tableView.reloadData()
                        }
                        return
                    }
                } else {
                    print(response!)
                }
                
                DispatchQueue.main.async {
                  self.hasSearched = false
                  self.tableView.reloadData()
                }
                
            })

          dataTask?.resume()

        }

        
    }
    
    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
     return .topAttached
   }
    
}

extension SearchViewController: UITableViewDelegate, UITableViewDataSource {
    
    
    func tableView(
      _ tableView: UITableView,
      numberOfRowsInSection section: Int
    ) -> Int {
      if !hasSearched {
        return 0
      } else if foodResult.foods.count == 0 {
        return 1
      } else {
          return foodResult.foods.count
      }
    }
    
    
    func tableView(
      _ tableView: UITableView,
      cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if foodResult.foods.count == 0 {
            return tableView.dequeueReusableCell(withIdentifier: TableView.CellIdentifiers.nothingFoundCell, for: indexPath)
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier:
              TableView.CellIdentifiers.searchResultCell, for: indexPath) as! SearchResultCell
            
            let searchResult = foodResult.foods[indexPath.row]
            cell.foodMacros.text = "\(searchResult.nf_calories)"
            cell.foodname.text = searchResult.food_name
            return cell
        }
       
        
    }
    
    /*
     de selects the row a user tapped. Makes it not grey
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "foodItem", sender: indexPath)
    }
    
    func tableView(
      _ tableView: UITableView,
      willSelectRowAt indexPath: IndexPath ) -> IndexPath? {
          
        if foodResult.foods.count == 0 {
        return nil
      } else {
        return indexPath
      }
    }
    
}
