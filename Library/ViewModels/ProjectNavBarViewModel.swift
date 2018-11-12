import KsApi
import Prelude
import ReactiveSwift
import Result

public protocol ProjectNavBarViewModelInputs {
  func closeButtonTapped()
  func configureWith(project: Project, refTag: RefTag?)
  func projectPageDidScrollToTop(_ didScrollToTop: Bool)
  func projectImageIsVisible(_ visible: Bool)
  func projectVideoDidFinish()
  func projectVideoDidStart()
  func viewDidLoad()
}

public protocol ProjectNavBarViewModelOutputs {
  var backgroundOpaqueAndAnimate: Signal<(opaque: Bool, animate: Bool), NoError> { get }

  /// Emits the category button's title text.
  var categoryButtonText: Signal<String, NoError> { get }

  /// Emits the tint color of the category button.
  var categoryButtonTintColor: Signal<UIColor, NoError> { get }

  /// Emits the color of the category button's title.
  var categoryButtonTitleColor: Signal<UIColor, NoError> { get }

  /// Emits two booleans that determine if the category is hidden, and if that change should be animated.
  var categoryHiddenAndAnimate: Signal<(hidden: Bool, animate: Bool), NoError> { get }

  /// Emits when the controller should be dismissed.
  var dismissViewController: Signal<(), NoError> { get }

  /// Emits a boolean that determines if the navBar should show dropShadow.
  var navBarShadowVisible: Signal<Bool, NoError> { get }

  /// Emits the name of the project
  var projectName: Signal<String, NoError> { get }

  var titleHiddenAndAnimate: Signal<(hidden: Bool, animate: Bool), NoError> { get }
}

public protocol ProjectNavBarViewModelType {
  var inputs: ProjectNavBarViewModelInputs { get }
  var outputs: ProjectNavBarViewModelOutputs { get }
}

public final class ProjectNavBarViewModel: ProjectNavBarViewModelType,
ProjectNavBarViewModelInputs, ProjectNavBarViewModelOutputs {

  public init() {
    let configuredProjectAndRefTag = Signal.combineLatest(
      self.projectAndRefTagProperty.signal.skipNil(),
      self.viewDidLoadProperty.signal
      )
      .map(first)

    let configuredProject = configuredProjectAndRefTag.map(first)

    self.categoryButtonText = configuredProject.map(Project.lens.category.name.view)
      .skipRepeats()

    self.categoryButtonTintColor = configuredProject.mapConst(discoveryPrimaryColor())

    self.categoryButtonTitleColor = self.categoryButtonTintColor

    self.projectName = configuredProject.map(Project.lens.name.view)

    let videoIsPlaying = Signal.merge(
      self.viewDidLoadProperty.signal.mapConst(false),
      self.projectVideoDidStartProperty.signal.mapConst(true),
      self.projectVideoDidFinishProperty.signal.mapConst(false)
    )

    let projectImageIsVisible = Signal.merge(
      self.projectImageIsVisibleProperty.signal,
      self.viewDidLoadProperty.signal.mapConst(true)
      )
      .skipRepeats()

    self.categoryHiddenAndAnimate = Signal.merge(
      self.viewDidLoadProperty.signal.mapConst((false, false)),

      Signal.combineLatest(projectImageIsVisible, videoIsPlaying)
        .map { projectImageIsVisible, videoIsPlaying in
          (videoIsPlaying ? true : !projectImageIsVisible, true)
        }
        .skip(first: 1)
      )
      .skipRepeats { $0.hidden == $1.hidden }

    self.navBarShadowVisible = Signal.merge(
      self.viewDidLoadProperty.signal.mapConst(true),
      self.projectPageDidScrollToTopProperty.signal
      )
      .skipRepeats()

    self.titleHiddenAndAnimate = Signal.merge(
      self.viewDidLoadProperty.signal.mapConst((true, false)),
      self.projectImageIsVisibleProperty.signal.map { ($0, true) }
      )
      .skipRepeats { $0.hidden == $1.hidden }

    self.backgroundOpaqueAndAnimate = Signal.merge(
      self.viewDidLoadProperty.signal.mapConst((false, false)),
      self.projectImageIsVisibleProperty.signal.map { (!$0, true) }
      )
      .skipRepeats { $0.opaque == $1.opaque }

    self.dismissViewController = self.closeButtonTappedProperty.signal

    configuredProjectAndRefTag
      .takeWhen(self.closeButtonTappedProperty.signal)
      .observeValues { project, refTag in
        AppEnvironment.current.koala.trackClosedProjectPage(project, refTag: refTag, gestureType: .tap)
    }
  }

  fileprivate let projectAndRefTagProperty = MutableProperty<(Project, RefTag?)?>(nil)
  public func configureWith(project: Project, refTag: RefTag?) {
    self.projectAndRefTagProperty.value = (project, refTag)
  }

  fileprivate let closeButtonTappedProperty = MutableProperty(())
  public func closeButtonTapped() {
    self.closeButtonTappedProperty.value = ()
  }

  fileprivate let projectImageIsVisibleProperty = MutableProperty(false)
  public func projectImageIsVisible(_ visible: Bool) {
    self.projectImageIsVisibleProperty.value = visible
  }

  fileprivate let projectPageDidScrollToTopProperty = MutableProperty(false)
  public func projectPageDidScrollToTop(_ didScrollToTop: Bool) {
    self.projectPageDidScrollToTopProperty.value = didScrollToTop
  }

  fileprivate let projectVideoDidFinishProperty = MutableProperty(())
  public func projectVideoDidFinish() {
    self.projectVideoDidFinishProperty.value = ()
  }

  fileprivate let projectVideoDidStartProperty = MutableProperty(())
  public func projectVideoDidStart() {
    self.projectVideoDidStartProperty.value = ()
  }

  fileprivate let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  public let backgroundOpaqueAndAnimate: Signal<(opaque: Bool, animate: Bool), NoError>
  public let categoryButtonText: Signal<String, NoError>
  public let categoryButtonTintColor: Signal<UIColor, NoError>
  public let categoryButtonTitleColor: Signal<UIColor, NoError>
  public let categoryHiddenAndAnimate: Signal<(hidden: Bool, animate: Bool), NoError>
  public let dismissViewController: Signal<(), NoError>
  public let navBarShadowVisible: Signal<Bool, NoError>
  public let projectName: Signal<String, NoError>
  public let titleHiddenAndAnimate: Signal<(hidden: Bool, animate: Bool), NoError>

  public var inputs: ProjectNavBarViewModelInputs { return self }
  public var outputs: ProjectNavBarViewModelOutputs { return self }
}
