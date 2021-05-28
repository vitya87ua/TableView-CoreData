//
//  TeethTableVC.swift
//  MyTooth
//
//  Created by Віктор Бережницький on 11.01.2021.
//

import UIKit
import CoreData

class TeethTableVC: UITableViewController, NSFetchedResultsControllerDelegate {
    
    var indexPathForLeadingSwipe: IndexPath?
    
    // Передача User по якому йде редагування/додавання
    var user: UserEntity?
    
    // Кількість записів ToothEntity у базі для даного UserEntity
    var teethCount: Int?
    
    // Витягуємо NSPersistentContainer
    var container: NSPersistentContainer?
    
    // Декларуємо NSFetchedResultsController
    var fetchedResultsController: NSFetchedResultsController<ToothEntity>!
    
    

    //    MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeFetchedResultsController()
        
        self.title = user?.firstName
        
        // Забирає лінії сепаратора внизу таблиці
        tableView.tableFooterView = UIView()
        
        // Фоновий надпис
        tableView.tableHeaderView = HeaderTableMessage().configure(count: fetchedResultsController.fetchedObjects?.count, vc: tableView, to: .tooth)

    }


    
//    MARK: - Communicating Data Changes to the Table View
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }


    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert: tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete: tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:  tableView.reloadRows(at: [indexPath!], with: .fade)
        case .move: tableView.moveRow(at: indexPath!, to: newIndexPath!)
        default: break
        }
        tableView.updateConstraintsIfNeeded()
    }


    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Фоновий надпис
        tableView.tableHeaderView = HeaderTableMessage().configure(count: fetchedResultsController.fetchedObjects?.count, vc: tableView, to: .tooth)
        tableView.endUpdates()
    }
    
    
    
    //    MARK: - Передача даних через "prepare for segue"
    
    // Передача даних в AddToothVC (Передаю цілу одиницю масиву)
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "addToothSegue" {
            let delegTo = segue.destination as! UINavigationController
            let top = delegTo.topViewController as! AddToothVC
            top.user = user
            top.container = container
            top.teethCount = teethCount
            
        } else if segue.identifier == "toothEventsSegue" {
            let delegTo = segue.destination as! ToothEventsVC
            delegTo.tooth = fetchedResultsController.object(at: tableView.indexPathForSelectedRow!)
            delegTo.user = user
            delegTo.container = container
            
            // передача зуба зразу аж в AddEditEventTVC з додаванням Event.
        } else if segue.identifier == "addEventFromToothTableSegue" {
            let delegTo = segue.destination as! AddEditEventTVC
            delegTo.tooth = fetchedResultsController.object(at: indexPathForLeadingSwipe!)
            delegTo.user = user
            delegTo.container = container
            
            // Передаємо кількість events для даного ToothEntity (StoreManager)
            delegTo.eventsCount = fetchedResultsController.object(at: indexPathForLeadingSwipe!).events?.count
        }
    }
    
    
    
    // MARK: - Table view DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        fetchedResultsController.sections!.count
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = fetchedResultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[section]
        return sectionInfo.numberOfObjects
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        guard let object = self.fetchedResultsController?.object(at: indexPath) else {
            fatalError("Attempt to configure cell without a managed object")
        }
        
        // Назва зуба
        cell.textLabel?.text = DataManager.toothNameFor(number: object)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 20)
        
        // Остання процедура по зубу
        let lastProcedure = ToothEntity.lastProcedure(tooth: object)
       
        // Якщо в зуб вирваний то повідомляємо про це, текст останні події заміняється на "видалений" і усі елементи клітинки стають бліді. Зуб стає вирваними якщо останній його запис вибраний "видалений"
        if !lastProcedure.isEmpty && object.isRemoved {
            cell.detailTextLabel?.text = NSLocalizedString("TeethTableVC.[REMOVED]", comment: "")
            cell.detailTextLabel?.textColor = .systemRed
            cell.detailTextLabel?.alpha = 0.4
            cell.textLabel?.alpha = 0.4
            cell.imageView?.alpha = 0.4
        } else {
            let detailText = !lastProcedure.isEmpty ? NSLocalizedString(lastProcedure, comment: "") : NSLocalizedString("TeethTableVC.[No entries yet]", comment: "")
            cell.detailTextLabel?.text = detailText
            cell.detailTextLabel?.textColor = .lightGray

        }
        
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 17)

        // Картинка
        cell.imageView?.image = UIImage(named: String(object.number))!

        return cell
    }
    
    
    
    //    MARK: - Hастройка таблиці
    
    // Висота клітинки
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 80 }
    
    
    // Дія при натиску на певну клітинку
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
//        print(fetchedResultsController?.object(at: indexPath).isPermanent, fetchedResultsController?.object(at: indexPath).isRemoved)
    }
    
    
    
    //    MARK: - NSFetchedResultsController
    
    // Створюємо NSFetchedResultsController
    private func initializeFetchedResultsController() {
        let request: NSFetchRequest<ToothEntity> = ToothEntity.fetchRequest()
        
        // Відсортовуємо масив зубів через NSSortDescriptor згідно користувацьких настройок
        let departmentSort = Settings.shared.sortDescriptorForTeeth()
        request.sortDescriptors = [departmentSort]
        
        // Відфільтровуємо через Предикат згідно користувацьких настройок
        let predicat = Settings.shared.predicateForTeeth(user: user!)
        request.predicate = predicat
        
        let moc = container!.viewContext
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
    }
    
    
    
    //    MARK: - Редагування клітинок
    
    // Дозволити редагування якщо нажата кнопка Edit, інакше редагування заборонене (тобто свайпом не можна)
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }
    
    
    // leadingSwipe - INSERT
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // передача індекса клітинки по який свайпнули
        indexPathForLeadingSwipe = indexPath
        
        let leadingAction = UIContextualAction(style: .normal, title: nil) { [self] (UIContextualAction, UIView, handler) in
            
            // Відкриваємо AddEditEventTVC
            performSegue(withIdentifier: "addEventFromToothTableSegue", sender: tableView)
            handler(true)
        }
        
        leadingAction.image = UIImage(systemName: "plus")
        leadingAction.backgroundColor = #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
        
        return UISwipeActionsConfiguration(actions: [leadingAction])
    }
    
    
    
    // trailingSwipe - DELETE
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let trailingAction = UIContextualAction(style: .destructive, title: nil) { [self] (UIContextualAction, UIView, handler) in
            
            // alert про видалення запису
            let message = NSLocalizedString("TeethTableVC.Are you sure you want to remove this tooth from the list?", comment: "")
            let alert = UIAlertController(title: "", message: message, preferredStyle: UIAlertController.Style.alert)
            
            
            let actionNo = UIAlertAction(title: NSLocalizedString("TeethTableVC.No", comment: ""), style: UIAlertAction.Style.cancel, handler: nil)
            
            let actionDel = UIAlertAction(title: NSLocalizedString("TeethTableVC.Delete", comment: ""), style: UIAlertAction.Style.destructive) {_ in
                let object = fetchedResultsController.object(at: indexPath)
                fetchedResultsController.managedObjectContext.delete(object)
                
                do {
                    try fetchedResultsController.managedObjectContext.save()
                } catch { }
            }
            
            alert.addAction(actionNo)
            alert.addAction(actionDel)
            present(alert, animated: true, completion: nil)
            
            handler(true)
        }
        trailingAction.image = UIImage(systemName: "trash")
        trailingAction.backgroundColor = .systemRed
        
        return UISwipeActionsConfiguration(actions: [trailingAction])
    }
    
    
    // MARK: - Header with message
    
    private func viewForHeader() -> UIView? {
        if fetchedResultsController.fetchedObjects == nil || fetchedResultsController.fetchedObjects?.isEmpty == true {
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 200))
            
            let messtageLabel = UILabel(frame: .zero)
            messtageLabel.numberOfLines = 0
            messtageLabel.text = "Tap ⨁\nfor add new user"
            messtageLabel.font = .systemFont(ofSize: 30)
            messtageLabel.textColor = .systemGray4
            messtageLabel.textAlignment = .center
            messtageLabel.sizeToFit()
            messtageLabel.center = headerView.center
            
            headerView.addSubview(messtageLabel)

            tableView.sectionHeaderHeight = 200
            
            return headerView
        } else {
            return nil
        }
    }
    
    
}
