import common
import lustre/element.{type Element}
import wisp.{type Request, type Response}

pub fn list_sessions(
  req: Request,
  model: List(common.GymSession),
) -> List(Element(a)) {
  todo
}
